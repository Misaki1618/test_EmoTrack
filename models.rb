require 'bundler/setup'
Bundler.require

ActiveRecord::Base.establish_connection

class User < ActiveRecord::Base
  has_secure_password
  
  validates :name,
  format: {with: URI::MailTo::EMAIL_REGEXP},
  presence: true

  validates :password, 
  length: { in: 5..10 }
    
  has_many :emotions
  has_many :musics
end

class Emotion < ActiveRecord::Base
  belongs_to :user
end

class Music < ActiveRecord::Base
  belongs_to :user
end

class Count < ActiveRecord::Base
 
end