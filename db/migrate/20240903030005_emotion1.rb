class Emotion1 < ActiveRecord::Migration[6.1]
  def change
    create_table :users do |t|
      t.string :name
      t.string :password_digest
      t.timestamps null:false
     end
    
    create_table :emotions do |t|
      t.references :user, foreign_key: true
      t.timestamps null:false
      t.integer :dissatisfaction
      t.integer :energy
      t.integer :stress
      t.text :diary
      t.string :emotion_name    # 選択された感情名（焦り、嬉しい等）
      t.string :emotion_type    # negative または positive
      t.string :status
      t.string :s
      t.string :d
      t.string :e
    end
    
    create_table :musics do |t|
      t.references :user, foreign_key: true
      t.string :url
      t.string :name
      t.boolean :favorite
      t.integer :tempo
      t.string :image
      t.timestamps null:false
    end
    
     create_table :counts do |t|
      t.integer :c
     end
  end
end
