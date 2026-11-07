# frozen_string_literal: true

class PixService
  pattr_initialize [:key!, :name!, :city!, [:amount, nil], [:txid, '***']]

  def payload
    parts = [
      format_field('00', '01'), # Payload Format Indicator
      format_field('26', merchant_account_info),
      format_field('52', '0000'), # Merchant Category Code
      format_field('53', '986'),  # Transaction Currency (986 = BRL)
      (format_field('54', format('%.2f', amount.to_f)) if amount.present? && amount.to_f.positive?),
      format_field('58', 'BR'),   # Country Code
      format_field('59', sanitize(name, 25)),
      format_field('60', sanitize(city, 15)),
      format_field('62', format_field('05', sanitize(txid, 25)))
    ].compact.join

    full_payload = "#{parts}6304"
    "#{full_payload}#{crc16(full_payload)}"
  end

  private

  def merchant_account_info
    [
      format_field('00', 'br.gov.bcb.pix'),
      format_field('01', key)
    ].join
  end

  def format_field(id, value)
    len = value.to_s.bytesize.to_s.rjust(2, '0')
    "#{id}#{len}#{value}"
  end

  def sanitize(str, max_len)
    ActiveSupport::Inflector.transliterate(str.to_s).gsub(/[^a-zA-Z0-9 ]/, '').strip[0, max_len]
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

