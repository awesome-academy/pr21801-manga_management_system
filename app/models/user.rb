class User < ApplicationRecord
  require "csv"

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :omniauthable, omniauth_providers: [:facebook, :google_oauth2]

  enum role: {user: 0, admin: 1}
  after_initialize :set_default_role, if: :new_record?
  ratyrate_rater
  acts_as_voter
  acts_as_paranoid

  has_many :comments, dependent: :destroy
  has_many :likes
  has_many :active_relationships, class_name: Relationship.name,
            foreign_key: "follower_id",
            dependent: :destroy
  has_many :following, through: :active_relationships, source: :followed
  has_many :events

  scope :load_data, -> {select(:id, :name, :email, :role)}

  validates_presence_of :name

  def set_default_role
    self.role ||= :user
  end

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do | user |
      user.email = auth.info.email
      user.name = auth.info.name
      user.provider = auth.provider
      user.uid = auth.uid
      user.password = Devise.friendly_token[0,10]
    end
  end

  def to_csv
    attributes = %w(id name email roles)
    CSV.generate(headers: true) do |csv|
      csv << attributes
      all.find_each do |user|
        csv << attributes.map { |attr| user.send(attr) }
      end
    end
  end

  def import(file)
    error_row = []
    index = 0
    CSV.foreach(file.path, headers: :true) do |row|
      user = User.new row.to_hash.merge(password: "12345678")
      index += 1
      unless user.save
        error_row << index
      end
    end
    error_row.join ", "
  end

  def follow(manga)
    following << manga
  end

  def unfollow(manga)
    following.delete(manga)
  end

  def following?(manga)
    following.include?(manga)
  end
end
