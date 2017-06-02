class CompanyEvent < ActiveRecord::Base
  validates :title, presence: true

  belongs_to :account
  has_many :files, as: :fileable, class_name: 'GenericFile', dependent: :destroy
end
