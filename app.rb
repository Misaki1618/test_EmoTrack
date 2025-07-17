require 'sinatra'
require 'bundler/setup'
Bundler.require
require 'net/http'
require 'uri'
require 'json'
require 'logger'
require './models.rb'
require 'thread'
require 'rspotify'
require 'active_support/all'
require 'dotenv'
require 'webrick'
set :server, 'webrick'
Dotenv.load unless ENV['RACK_ENV'] == 'production'
require_relative 'musics'
require_relative 'emotion_classifier'
enable :sessions
RSpotify.authenticate(ENV['SPOTIFY_CLIENT_ID'], ENV['SPOTIFY_SECRET_ID'])
set :public_folder,'public'
UPLOADS_DIR='public/uploads'
set :port, ENV['PORT'] || 4567

ActiveRecord.default_timezone = :utc


helpers do
    def current_user
        User.find_by(id:session[:user])
    end
end

before do
  if session[:user].nil?
    redirect '/' unless request.path_info == '/' || request.path_info == '/signup' || request.path_info == '/signin'
  end
end


get '/e' do
  erb:eemotion
end
get '/emotion' do
 
  count_record = Count.first || Count.create(c: 0)
  
  # カウントを1増やす
  count_record.update(c: count_record.c + 1)
  
  # 奇数か偶数かで表示するテンプレートを分岐
  if count_record.c.odd?
     session[:an]='more'
    erb :emotion
  else
    session[:an]='less'
    erb :eemotion
  end
end
get '/logout' do
  session[:user]=nil
  redirect '/'
end

post '/upload/:filename' do
    emotion_id = session[:current_emotion_id]
    if emotion_id
    # 現在のユーザーの感情記録のみ更新可能
        emotion = current_user.emotions.find_by(id: emotion_id)
        
        if emotion && emotion.status == "in_progress"
            diary=params[:diary]
            filename=params[:filename]
            filepath=File.join(UPLOADS_DIR, filename)
            session_id=session[:user]
          
            Thread.new(session_id) do |session_id|
                current_user=User.find_by(id: session_id)
                output= `ruby amivoice.rb #{filepath}`
                response=JSON.parse(output)
                total_dissatisfaction=0
                total_energy=0
                total_stress=0
                count=0
            
                if response["status"]=="error"||!response["sentiment_analysis"]["segments"].present?
                    emotion.update(
                        status: "error",
                        diary: diary,
                        stress: 0,
                        energy: 0,
                        dissatisfaction: 0,
                        e: "a",
                        d: "a",
                        s: "a"
                    )
                    File.delete(filepath) if File.exist?(filepath)
                elsif response["status"]=="completed"
                    segments=response["sentiment_analysis"]["segments"]
                
                    segments.each do |segment|
                        total_dissatisfaction+=segment["dissatisfaction"]
                        total_energy+=segment["energy"]
                        total_stress+=segment["stress"]
                        count+=1
                    end
                    classifier=EmotionClassifier.new(total_dissatisfaction,total_energy,total_stress,count)
                        
                    dissatisfaction=classifier.dissatisfaction
                    energy=classifier.energy
                    stress=classifier.stress
                        
                    average_dissatisfaction=classifier.average_dissatisfaction
                    average_energy=classifier.average_energy
                    average_stress=classifier.average_stress
             
                    aa=emotion.update(
                        status: "completed",
                        diary: diary,
                        stress: average_stress,
                        energy:  average_energy,
                        dissatisfaction: average_dissatisfaction,
                        s: stress,
                        e: energy,
                        d: dissatisfaction
                    )
                    File.delete(filepath) if File.exist?(filepath)
                end
                
                
            end 
            
            erb:load
        end
    else
        redirect '/'
    end
    
end


post '/audio_upload' do
  Dir.mkdir('public/uploads') unless Dir.exist?('public/uploads')
     emotion_id = session[:current_emotion_id]
    @emotion = current_user.emotions.find_by(id: emotion_id)
    audio=params[:audio]
    filename=audio[:filename]
    filepath=File.join(UPLOADS_DIR, filename)
    File.open(filepath, 'wb') do |f|
      f.write(audio[:tempfile].read)
    end
   
    output=`ruby groq.rb #{filepath}`
    response = JSON.parse(output)
    @filename=filename
    if params[:text].present?
         @text=params[:text]+response["text"]
    else
         @text=response["text"]
    end
   
  
    @question = case @emotion.emotion_name
    when "焦り"
      "どんなことで焦ってしまいましたか？"
    when "罪悪感"
      "どんなことがあって、罪悪感を感じましたか？"
    when "嫌悪"
      "何に対して嫌だなと感じましたか？"
    when "怒り"
      "どんなことがあって怒りを感じましたか？"
    when "恥"
      "どんなことで恥ずかしさを感じましたか？"
    when "不安"
      "どんなことが不安に感じましたか？"
    when "悲しい"
      "どんなことで悲しくなりましたか？"
    when "達成感"
      "どんなことができて、達成感を感じましたか？"
    when "平穏"
      "どんなときに、穏やかな気持ちになれましたか？"
    when "楽しい"
      "どんなことで楽しい気持ちになりましたか？"
    when "嬉しい"
      "どんなことが嬉しかったですか？"
    when "ワクワク"
      "どんなことにワクワクしましたか？"
    when "誇り"
      "どんなことに誇りを感じましたか？"
    else
      "その感情について、もう少し教えてください。"
    end
    erb:index
    
    
    
end


get '/' do
    puts "Current environment: #{settings.environment}"
    if session[:user].nil?
        erb:signin
    else
       redirect '/home'
    end
   
end

post '/signin' do
    user=User.find_by(name:params[:name])

    if user && user.authenticate(params[:password])
        session[:user]=user.id
        @emotions=Emotion.where(user_id: current_user.id)
        @timeline=Emotion.where(user_id: current_user.id)
        @color="all"
        puts "aaaaaaaaaaaaaaaaaaa:#{@emotions.present?}"
        erb:home
    else
        @error = user.nil? ? "メールアドレスが見つかりません" : "パスワードが正しくありません"
        erb:signin
    end
  
end

get '/result' do
    emotion=current_user.emotions.order(id: :desc).first
    
    if emotion.status=="error"||!emotion.s.present?
        @error="録音に失敗しました"
        erb:emotion
    else

        #解析結果の取得
        @d1=emotion.d
        @e1=emotion.e
        @s1=emotion.s
    
        #spotifyAPIの使用
        if @s1=="やや高い"||@s1=="高い"
            track=SPOTIFY.sample
            track_name=track[0]
            track_url=track[2]
            track_tempo=track[1]
            current_user.musics.create(
            url: track_url,
            name: track_name,
            image: "a",
            tempo: track_tempo
            )
        else
            playlist_ids = [
                "63KqNW4EVV3PMnTj6DSCwU",
                "2ueDXPsvpcfjMFql9l4twB",
                "5OwbU0xeKv0mc0gWeqt5M0"
            ]

            # ランダムなプレイリストを選ぶ
            playlist_id = playlist_ids.sample
            playlist = RSpotify::Playlist.find_by_id(playlist_id)


            track = playlist.tracks.sample

            track_name = track.name
            track_url = track.external_urls["spotify"]
            track_image1 = track.album.images.dig(0, "url")

            
            current_user.musics.create(
            url: track_url,
            name: track_name,
            image: track_image1,
            tempo: 20
            )
        end
        @spotify=current_user.musics.order(id: :desc).first
        if session[:an] == 'more'
          @url = 'https://docs.google.com/forms/d/e/1FAIpQLScRdHO978wP3TixfN6ooPWAnQVHDKoXYnEpMZoGshkLk8g4sw/viewform?usp=dialog'
        else
          @url = 'https://docs.google.com/forms/d/e/1FAIpQLSfeg31mUUP2A_lHOLbA17ffHcNBeTSWNNSt2Al_D7Qe1gjdtA/viewform?usp=dialog'  # デフォルト値
        end
        erb:result
    end
end 

get '/signup' do
    erb:signup
end

post '/signup' do
    user=User.create(
    name:params[:name],
    password:params[:password],
    password_confirmation:params[:password_confirmation]
    )
    if user.save
        session[:user]=user.id
         @emotions=current_user.emotions.all
         @timeline=current_user.emotions.all
         @color="all"
        erb:home
    end
    
end

get '/create' do
  # ログインチェック
  redirect '/login' unless current_user
  
  # URLパラメータから選択された感情を取得
  @selected_emotion = params[:emotion]
  
  # 感情のタイプを判定
  negative_emotions = ["焦り", "罪悪感", "嫌悪", "怒り", "恥", "不安", "悲しい"]
  positive_emotions = ["達成感", "平穏", "楽しい", "嬉しい","ワクワク","誇り"]
  
  @emotion_type = if negative_emotions.include?(@selected_emotion)
    "negative"
  elsif positive_emotions.include?(@selected_emotion)
    "positive"
  else
    nil
  end
  
  # 新しい感情記録を作成（status: "in_progress"で一時保存）
  @emotion = current_user.emotions.create(
    emotion_name: @selected_emotion,
    emotion_type: @emotion_type,
    status: "in_progress"  # 日記入力完了後に "completed" に更新
  )
  @question=""
 
  session[:current_emotion_id] = @emotion.id
  
    @question = case @selected_emotion
    when "焦り"
      "どんなことで焦ってしまいましたか？"
    when "罪悪感"
      "どんなことがあって、罪悪感を感じましたか？"
    when "嫌悪"
      "何に対して嫌だなと感じましたか？"
    when "怒り"
      "どんなことがあって怒りを感じましたか？"
    when "恥"
      "どんなことで恥ずかしさを感じましたか？"
    when "不安"
      "どんなことが不安に感じましたか？"
    when "悲しい"
      "どんなことで悲しくなりましたか？"
    when "達成感"
      "どんなことができて、達成感を感じましたか？"
    when "平穏"
      "どんなときに、穏やかな気持ちになれましたか？"
    when "楽しい"
      "どんなことで楽しい気持ちになりましたか？"
    when "嬉しい"
      "どんなことが嬉しかったですか？"
    when "ワクワク"
      "どんなことにワクワクしましたか？"
    when "誇り"
      "どんなことに誇りを感じましたか？"
    else
      "その感情について、もう少し教えてください。"
    end

  erb :index  # 日記入力画面を表示
end


get '/check_result' do
    time=Time.now.utc
    ten_seconds_ago=time-7.0
    record=current_user.emotions.find_by(updated_at: ten_seconds_ago..time)

    if record.nil?
        {status: 'yet'}.to_json
    else
        {status: 'completed'}.to_json
    end

end

get '/home' do
    @emotions=Emotion.where(user_id: current_user.id)
    @timeline=Emotion.where(user_id: current_user.id)
    @color="all"
    erb:home
end

get '/low_stress' do
    @emotions=Emotion.where(user_id: current_user.id)
    @timeline=Emotion.where(user_id: current_user.id).where(s: ["やや低い","低い"])
    @color="low"
    erb:home
end

get "/statistics" do
    one_months_ago=Time.now.utc-1.months
    @emotions2=current_user.emotions.where(created_at: one_months_ago..Time.now.utc) 
    erb:onemonth
end

get "/all" do
    @emotions2=current_user.emotions
    erb:all
end

get "/week" do
    one_week_ago=Time.now.utc-1.week
    @emotions2=current_user.emotions.where(created_at: one_week_ago..Time.now.utc)
    erb:week
end

get '/threemonth' do
    three_months_ago=Time.now.utc-1.months
    @emotions2=current_user.emotions.where(created_at: three_months_ago..Time.now.utc) 
    erb:threemonth
end

get '/allmusic' do
    @musics=current_user.musics.order(id: :desc)
    @page="all"
    erb:music
end

get '/calmmusic' do
    @musics=current_user.musics.where(tempo: 60..80)
    @page="calm"
    erb:music
end

get '/fastmusic' do
    @musics=current_user.musics.where("tempo >= ?", 80)
    @page="fast"
    erb:music
end

get '/favorites' do
    @musics=current_user.musics.where(favorite:true)
    @page="favorite"
    erb:music
end

post '/:id/:type/favorite' do
    record=current_user.musics.find_by(id:params[:id])
    
    if record.favorite!=false
        record.update({favorite:false})
    else
        record.update({favorite:true})
    end
    
    if params[:type]=="all"
        redirect '/allmusic'
    elsif params[:type]=="calm"
        redirect '/calmmusic'
    elsif params[:type]=="fast"
        redirect '/fastmusic'
    elsif params[:type]=="favorite"
        redirect '/favorites'
    end
    
end

get "/test" do
    erb:test2
end