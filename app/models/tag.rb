class Tag < ApplicationRecord
  has_many :product_tags, dependent: :destroy
  has_many :products, through: :product_tags

  validates :name_nm, presence: true, uniqueness: true
  validates :color_code_nm, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_blank: true

  scope :ordered, -> { order(:name_nm) }
end
