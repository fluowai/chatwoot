# frozen_string_literal: true

class Api::V1::Accounts::BrazilToolsController < Api::V1::Accounts::BaseController
  def pix
    pix_params = params.permit(:key, :name, :city, :amount, :txid, :key_type, :description)
    resolved_key = pix_params[:key].presence || GlobalConfigService.load('PIX_DEFAULT_KEY', nil)
    resolved_name = pix_params[:name].presence || GlobalConfigService.load('PIX_MERCHANT_NAME', nil) || Current.account.name
    resolved_city = pix_params[:city].presence || GlobalConfigService.load('PIX_MERCHANT_CITY', 'SAO PAULO')

    if resolved_key.blank?
      render json: { error: 'Chave PIX é obrigatória' }, status: :unprocessable_entity
      return
    end

    service = PixService.new(
      key: resolved_key,
      name: resolved_name,
      city: resolved_city,
      amount: pix_params[:amount],
      txid: pix_params[:txid].presence || '***',
      key_type: pix_params[:key_type],
      description: pix_params[:description]
    )

    render json: {
      payload: service.payload,
      formatted_amount: service.formatted_brl_amount,
      formatted_message: service.formatted_chat_message
    }
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def cep
    digits = params[:cep].to_s.gsub(/\D/, '')
    unless digits.length == 8
      render json: { error: 'CEP inválido. Informe 8 dígitos.' }, status: :unprocessable_entity
      return
    end

    response = HTTParty.get("https://viacep.com.br/ws/#{digits}/json/", timeout: 8)
    parsed = response.parsed_response
    if !response.success? || !parsed.is_a?(Hash) || parsed['erro']
      render json: { error: 'CEP não encontrado.' }, status: :not_found
      return
    end

    render json: {
      cep: parsed['cep'],
      street: parsed['logradouro'],
      complement: parsed['complemento'],
      neighborhood: parsed['bairro'],
      city: parsed['localidade'],
      state: parsed['uf'],
      ibge: parsed['ibge'],
      ddd: parsed['ddd']
    }
  rescue StandardError => e
    render json: { error: "Falha ao consultar ViaCEP: #{e.message}" }, status: :bad_gateway
  end

  def validate_document
    raw_doc = params[:document].to_s
    valid = Brazil::DocumentValidator.valid_document?(raw_doc)
    render json: {
      valid: valid,
      type: Brazil::DocumentValidator.document_type(raw_doc),
      formatted: valid ? Brazil::DocumentValidator.format_document(raw_doc) : raw_doc
    }
  end

  def whatsapp_status
    inbox = Current.account.inboxes.find(params[:inbox_id])
    authorize inbox, :show?

    unless inbox.channel_type == 'Channel::Whatsapp' && inbox.channel.unofficial_provider?
      render json: { error: 'Caixa de entrada não utiliza provedor não oficial' }, status: :unprocessable_entity
      return
    end

    provider_service = inbox.channel.provider_service
    status_data = provider_service.respond_to?(:connection_status) ? provider_service.connection_status : { state: 'unknown' }
    qr_data = if ActiveModel::Type::Boolean.new.cast(params[:include_qr]) && provider_service.respond_to?(:fetch_qr_code)
                provider_service.fetch_qr_code
              else
                {}
              end

    render json: {
      inbox_id: inbox.id,
      provider: inbox.channel.provider,
      webhook_url: "#{ENV.fetch('FRONTEND_URL', request.base_url).chomp('/')}/webhooks/whatsapp/#{ERB::Util.url_encode(inbox.channel.phone_number)}",
      status: status_data,
      qrcode: qr_data
    }
  end
end
