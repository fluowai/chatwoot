# frozen_string_literal: true

module Brazil
  module DocumentValidator
    module_function

    def clean_digits(value)
      value.to_s.gsub(/\D/, '')
    end

    def valid_cpf?(value)
      digits = clean_digits(value)
      return false unless digits.length == 11
      return false if digits.chars.uniq.length == 1

      nums = digits.chars.map(&:to_i)
      first_check = calculate_cpf_digit(nums[0, 9], 10)
      return false unless nums[9] == first_check

      second_check = calculate_cpf_digit(nums[0, 10], 11)
      nums[10] == second_check
    end

    def valid_cnpj?(value)
      digits = clean_digits(value)
      return false unless digits.length == 14
      return false if digits.chars.uniq.length == 1

      nums = digits.chars.map(&:to_i)
      weights_first = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
      weights_second = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]

      first_check = calculate_cnpj_digit(nums[0, 12], weights_first)
      return false unless nums[12] == first_check

      second_check = calculate_cnpj_digit(nums[0, 13], weights_second)
      nums[13] == second_check
    end

    def valid_document?(value)
      digits = clean_digits(value)
      case digits.length
      when 11 then valid_cpf?(digits)
      when 14 then valid_cnpj?(digits)
      else false
      end
    end

    def document_type(value)
      digits = clean_digits(value)
      return 'CPF' if digits.length == 11 && valid_cpf?(digits)
      return 'CNPJ' if digits.length == 14 && valid_cnpj?(digits)

      nil
    end

    def format_document(value)
      digits = clean_digits(value)
      if digits.length == 11
        "#{digits[0, 3]}.#{digits[3, 3]}.#{digits[6, 3]}-#{digits[9, 2]}"
      elsif digits.length == 14
        "#{digits[0, 2]}.#{digits[2, 3]}.#{digits[5, 3]}/#{digits[8, 4]}-#{digits[12, 2]}"
      else
        value.to_s
      end
    end

    def calculate_cpf_digit(slice, start_weight)
      sum = slice.each_with_index.sum { |num, idx| num * (start_weight - idx) }
      remainder = (sum * 10) % 11
      remainder == 10 ? 0 : remainder
    end

    def calculate_cnpj_digit(slice, weights)
      sum = slice.each_with_index.sum { |num, idx| num * weights[idx] }
      remainder = sum % 11
      remainder < 2 ? 0 : 11 - remainder
    end
  end
end
