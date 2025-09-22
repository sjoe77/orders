class Address < ApplicationRecord
  include TableConfigurable

  has_paper_trail

  belongs_to :customer

  validates :address_type_nm, presence: true, inclusion: { in: %w[shipping billing] }
  validates :address_line1_txt, presence: true
  validates :city_nm, presence: true
  validates :state_nm, presence: true
  validates :postal_code_nm, presence: true
  validates :country_code_nm, presence: true

  scope :shipping, -> { where(address_type_nm: 'shipping') }
  scope :billing, -> { where(address_type_nm: 'billing') }
  scope :default, -> { where(is_default_flag: true) }

  configure_table do
    column :address_type_nm, format: 'string', sortable: true
    column :address_line1_txt, format: 'string', sortable: true
    column :city_nm, format: 'string', sortable: true
    column :state_nm, format: 'string', sortable: true
    column :postal_code_nm, format: 'string', sortable: true
    column :is_default_flag, format: 'boolean', sortable: true
  end

  def full_address
    lines = [address_line1_txt, address_line2_txt].compact
    lines << "#{city_nm}, #{state_nm} #{postal_code_nm}"
    lines << country_code_nm unless country_code_nm == 'US'
    lines.join("\n")
  end
end
