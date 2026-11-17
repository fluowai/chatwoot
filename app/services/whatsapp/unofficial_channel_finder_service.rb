# frozen_string_literal: true

class Whatsapp::UnofficialChannelFinderService
  pattr_initialize [:phone_number, :instance_name]

  def perform
    find_by_phone_candidates || find_by_instance_name
  end

  private

  def find_by_phone_candidates
    return if phone_number.blank?

    candidates = build_phone_candidates(phone_number)
    return if candidates.blank?

    Channel::Whatsapp.where(phone_number: candidates).first
  end

  def find_by_instance_name
    return if instance_name.blank?

    normalized_instance = instance_name.to_s.strip
    return if normalized_instance.blank?

    provider_config_attr = Channel::Whatsapp.arel_table[:provider_config]
    instance_match = Arel::Nodes::InfixOperation.new('->>', provider_config_attr, Arel::Nodes.build_quoted('instance_name'))
                                                .eq(normalized_instance)
    session_match = Arel::Nodes::InfixOperation.new('->>', provider_config_attr, Arel::Nodes.build_quoted('session_id'))
                                               .eq(normalized_instance)

    Channel::Whatsapp.where(instance_match.or(session_match)).first
  end

  def build_phone_candidates(raw_phone)
    clean = raw_phone.to_s.gsub(/\D/, '')
    return [raw_phone.to_s] if clean.blank?

    normalizer = Whatsapp::PhoneNormalizers::BrazilPhoneNormalizer.new
    base_numbers = if normalizer.handles_country?(clean)
                     normalizer.contact_candidates(clean)
                   else
                     [clean]
                   end

    base_numbers.flat_map { |num| [num, "+#{num}"] }.push(raw_phone.to_s).compact_blank.uniq
  end
end
