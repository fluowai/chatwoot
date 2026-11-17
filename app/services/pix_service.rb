# frozen_string_literal: true

class PixService
  EVP_UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  pattr_initialize [:key!, :name!, [:city, 'SAO PAULO'], [:amount, nil], [:txid, '***'], [:key_type, nil], [:description, nil]]

  def payload
    raise ArgumentError, 'PIX key is required' if normalized_key.blank?
    raise ArgumentError, 'Merchant name is required' if sanitized_name.blank?

    parts = [
      format_field('00', '01'),
      format_field('26', merchant_account_info),
      format_field('52', '0000'),
      format_field('53', '986'),
      formatted_amount_field,
      format_field('58', 'BR'),
      format_field('59', sanitized_name),
      format_field('60', sanitized_city),
      format_field('62', format_field('05', sanitized_txid))
    ].compact.join

    full_payload = "#{parts}6304"
    "#{full_payload}#{crc16(full_payload)}"
  end

  def formatted_brl_amount
    return nil unless numeric_amount.positive?

    inteiro, centavos = format('%.2f', numeric_amount).split('.')
    inteiro_formatado = inteiro.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse
    "R$ #{inteiro_formatado},#{centavos}"
  end

  def formatted_chat_message
    lines = ['💠 *Pagamento via PIX*']
    lines << "*Recebedor:* #{name.to_s.strip}"
    lines << "*Valor:* #{formatted_brl_amount}" if formatted_brl_amount.present?
    lines << "*Descrição:* #{description.to_s.strip}" if description.present?
    lines << ''
    lines << '*PIX Copia e Cola:*'
    lines << payload
    lines.join("\n")
  end

  private

  def numeric_amount
    @numeric_amount ||= amount.to_s.tr(',', '.').to_f.round(2)
  end

  def formatted_amount_field
    return nil unless numeric_amount.positive?

    format_field('54', format('%.2f', numeric_amount))
  end

  def merchant_account_info
    fields = [
      format_field('00', 'br.gov.bcb.pix'),
      format_field('01', normalized_key)
    ]
    if description.present?
      clean_desc = sanitize_text(description, 40)
      fields << format_field('02', clean_desc) if clean_desc.present?
    end
    fields.join
  end

  def normalized_key
    @normalized_key ||= begin
      raw = key.to_s.strip
      if raw.include?('@')
        raw.downcase
      elsif raw.match?(EVP_UUID_PATTERN)
        raw.downcase
      elsif key_type.to_s == 'phone' || raw.start_with?('+')
        digits = raw.gsub(/\D/, '')
        digits = "55#{digits}" if digits.length.in?(10..11)
        "+#{digits}"
      else
        digits = raw.gsub(/\D/, '')
        digits.length.in?([11, 14]) ? digits : raw
      end
    end
  end

  def sanitized_name
    sanitize_text(name, 25)
  end

  def sanitized_city
     sanitize_text(city.presence || 'SAO PAULO', 15).presence || 'SAO PAULO'
  end

  def sanitized_txid
    raw = txid.to_s.strip
    return '***' if raw.blank? || raw == '***'

    cleaned = ActiveSupport::Inflector.transliterate(raw).gsub(/[^a-zA-Z0-9]/, '')[0, 25]
    cleaned.presence || '***'
  end

  def format_field(id, value)
    len = value.to_s.bytesize.to_s.rjust(2, '0')
    "#{id}#{len}#{value}"
  end

  def sanitize_text(str, max_len)
    ActiveSupport::Inflector.transliterate(str.to_s)
                           .gsub(/[^a-zA-Z0-9 ]/, '')
                           .squeeze(' ')
                           .strip[0, max_len]
  end

  def crc16(str)
    crc = 0xFFFF
    str.bytes.each do |b|
      crc ^= (b << 8)
      8.times do
        crc = if (crc & 0x8000) != 0
                ((crc << 1) ^ 0x1021) & 0xFFFF
              else
                (crc << 1) & 0xFFFF
              end
      end
    end
    crc.to_s(16).upcase.rjust(4, '0')
  end
end
