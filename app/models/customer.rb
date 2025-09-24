class Customer < ApplicationRecord
  include TableConfigurable
  include Paginatable

  has_paper_trail meta: { audit_transaction_id: :paper_trail_audit_transaction_id }
  attr_accessor :audit_reason

  has_many :addresses, dependent: :destroy
  has_many :orders, dependent: :destroy

  accepts_nested_attributes_for :addresses, reject_if: :all_blank, allow_destroy: true

  validates :customer_key_nm, presence: true, uniqueness: true
  validates :customer_num, presence: true, uniqueness: true
  validates :company_name_nm, presence: true
  validates :email_nm, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :credit_limit_amt, numericality: { greater_than_or_equal_to: 0 }

  before_validation :generate_customer_num, on: :create

  scope :active, -> { where(active_flag: true) }
  scope :by_company, ->(name) { where("company_name_nm ILIKE ?", "%#{name}%") }

  configure_table do
    # Basic columns only for now
    column :customer_num, format: 'string', sortable: true
    column :company_name_nm, format: 'string', sortable: true
    column :contact_first_name_nm, format: 'string', sortable: true
    column :contact_last_name_nm, format: 'string', sortable: true
    column :email_nm, format: 'email', sortable: true
    column :credit_limit_amt, format: 'currency', sortable: true
    column :active_flag, format: 'boolean', sortable: true

    # Search configuration
    searchable :company_name_nm, :contact_first_name_nm, :contact_last_name_nm, :email_nm

    # Table configuration
    per_page_options 10, 25, 50
    default_per_page 10
    default_sort field: :company_name_nm, direction: :asc
  end

  def full_contact_name
    [contact_first_name_nm, contact_last_name_nm].compact.join(' ')
  end

  def display_name
    company_name_nm.presence || full_contact_name
  end

  def paper_trail_audit_transaction_id
    PaperTrail.request.controller_info[:audit_transaction_id] if PaperTrail.request.controller_info
  end

  private

  def generate_customer_num
    return if customer_num.present?

    last_customer = Customer.order(:customer_num).last
    next_num = last_customer ? last_customer.customer_num.gsub(/\D/, '').to_i + 1 : 1
    self.customer_num = "CUST-#{next_num.to_s.rjust(6, '0')}"
  end
end
