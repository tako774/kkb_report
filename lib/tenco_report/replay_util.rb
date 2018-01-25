# coding: utf-8
require 'zlib'
require 'rexml/document'

class String
  def pass(enc)
    self
  end
  alias :force_encoding :pass if !self.new.respond_to?(:force_encoding)
end

module TencoReport
  module ReplayUtil
    
    # 対戦結果に対応する対戦結果とリプレイファイルパスを取得
    # file_num を上限個数とする
    def get_replay_files(trackrecords, replay_config_path, file_num)
      replay_format = get_replay_format(replay_config_path)
      # config.ini は CP932 で記述されているので UTF-8 に一度変換
      replay_format = NKF.nkf('-Swxm0 --cp932', replay_format)
      
      #日付記号　%year %month %day
      #日付一括記号　%yymmdd %mmdd
      #時刻記号　%hour %min %sec
      #時刻一括記号　%hhmmss %hhmm
      #使用プロファイル　%p1 %p2
      #使用キャラクター　%c1 %c2
      #バージョン記号  　%ver
      pattern = /%(year|month|day|yymmdd|yymm|hour|min|sec|hhmmss|hhmm|p1|p2|c1|c2|ver)/
      replay_files = []
      trackrecords.shuffle.each do |tr|
        tr_time = Time.parse(tr['timestamp'])
        tr_replay_files = [tr_time - 15, tr_time, tr_time + 15].map do |time|
          # クライアントの場合、リプレイファイルは自身の情報がp2に入る
          # 対戦結果記録ツールでは、常に自身の情報がp1に入る
          # ホストでもクライアントでもリプレイファイルがとれるよう、
          # p1とp2を入れ替えた対戦結果を元にしたリプレイファイルも検索する
          tr1 = tr.clone
          tr2 = tr.clone
          tr2['p1name'] = tr['p2name']
          tr2['p2name'] = tr['p1name']
          tr2['p1id'] = tr['p2id']
          tr2['p2id'] = tr['p1id']
          tr2['p1win'] = tr['p2win']
          tr2['p2win'] = tr['p1win']
          [tr1, tr2].map do |tr|
            conversion = {
              "%year"   => time.year.to_s[2..3],
              "%month"  => sprintf("%02d", time.month),
              "%day"    => sprintf("%02d", time.day),
              "%yymm"   => time.year.to_s[2..3] + sprintf("%02d", time.month),
              "%yymmdd" => time.year.to_s[2..3] + sprintf("%02d", time.month) + sprintf("%02d", time.day),
              "%hour"   => sprintf("%02d", time.hour),
              "%min"    => sprintf("%02d", time.min),
              "%sec"    => "*", # 結果記録とリプレイファイルのタイムスタンプは7秒くらいはずれる
              "%hhmm"   => sprintf("%02d", time.hour) + sprintf("%02d", time.min),
              "%hhmmss" => sprintf("%02d", time.hour) + sprintf("%02d", time.min) + "*",
              "%p1"  => tr['p1name'],
              "%p2"  => tr['p2name'],
              "%c1"  => "*",
              "%c2"  => "*",
              "%ver" => "*"
            }
            replay_file_pattern = replay_format.gsub(pattern) { |str| conversion[str] }
            replay_file_pattern = "#{File.dirname(replay_config_path)}\\replay\\#{replay_file_pattern}*"
            replay_file_pattern.gsub!("\\", "/")
            replay_file_pattern.gsub!(/\*+/, "*")
            # UTF-8 から SJIS へ
            replay_file_pattern = NKF.nkf('-Wsxm0 --cp932', replay_file_pattern)
            Dir.glob(replay_file_pattern)
          end
        end
        
        tr_replay_files.flatten!.uniq!
        if !tr_replay_files[0].nil? then
          replay_files.push({ :trackrecord => tr, :path => tr_replay_files[0] })
          if replay_files.length >= file_num then
            replay_files = replay_files[0..(file_num - 1)]
            break
          end
        else
          # puts "リプレイファイルが見つけられませんでした。"
        end
        
      end
      replay_files
    end

    # リプレイデータ引数とし、匿名化したデータを返す
    # 2018/1/25 時点、リプレイファイルに匿名化が必要なデータが入っていないことを確認済み
    # def mask_replay_data(data)
    #   meta_data_length = get_meta_data_length(data)
    #   
    #   meta_data = inflate_meta_data(data)
    #   masked_meta_data = mask_meta_data(meta_data)
    #   compressed_masked_meta_data = Zlib::Deflate.deflate(masked_meta_data)
    #  
    #   File.open("last_body_data.dat", "wb") { |io| io.print data[(21 + meta_data_length)..-1] }
    #   data.slice(0, 9) +
    #   [compressed_masked_meta_data.length + 8].pack("I") + 
    #   [compressed_masked_meta_data.length].pack("I") + 
    #   [masked_meta_data.length].pack("I") + 
    #   compressed_masked_meta_data +
    #   data[(21 + meta_data_length)..-1]
    # end
    
    # replayPosting XML生成
    def make_replay_posting_xml(trackrecord, game_id, account_name, account_password)
      xml = REXML::Document.new
      xml << REXML::XMLDecl.new('1.0', 'UTF-8')
      
      # replayPosting 要素生成
      root = xml.add_element('replayPosting')
      
      # account 要素生成
      account_element = root.add_element('account')
      account_element.add_element('name').add_text(account_name.to_s)
      account_element.add_element('password').add_text(account_password.to_s)
      
      # game 要素生成
      game_element = root.add_element('game')
      game_element.add_element('id').add_text(game_id.to_s)
      
      # trackrecord 要素生成
      trackrecord_element = game_element.add_element('trackrecord')
      trackrecord_element.add_element('timestamp').add_text(trackrecord['timestamp'].to_s)
      trackrecord_element.add_element('p1name').add_text(trackrecord['p1name'].to_s)
      trackrecord_element.add_element('p1type').add_text(trackrecord['p1id'].to_s)
      trackrecord_element.add_element('p1point').add_text(trackrecord['p1win'].to_s)
      trackrecord_element.add_element('p2name').add_text(trackrecord['p2name'].to_s)
      trackrecord_element.add_element('p2type').add_text(trackrecord['p2id'].to_s)
      trackrecord_element.add_element('p2point').add_text(trackrecord['p2win'].to_s)
      
      xml.to_s
    end
    
    private

    # ゲーム側のリプレイファイル名のフォーマット設定を取得
    def get_replay_format(replay_config_path)

      # 2018/1/24時点で憑依華側が config.ini でのリプレイファイルパス指定を未実装のため固定値
      replay_format = '%yymmdd\replay_%hhmmss.rep'

      # replay_config_path_cp932 = NKF.nkf('-Wsxm0 --cp932', replay_config_path)
      # 
      # File.open(replay_config_path_cp932, "r") do |io|
      #   while (line = io.gets) do
      #     if line.strip =~ /\Afile_vs="?([^"]+)"?/ then
      #       replay_format = $1
      #       break
      #     end
      #   end
      # end
      # replay_format
    end
        
    # 元の圧縮された状態でのメタデータの長さを取得する
    # 4byte TFRP
    # 5byte unknown data 00 02 24 16 00
    # 4byte first_block_length (= compressed data length + 8)
    # 4byte compressed meta data length
    # 4byte uncompressed meta data length
    # zlib compressed meta data
    # rest data
    def get_meta_data_length(data)
      idx = 13
      data.slice(idx, 4).unpack("I")[0]
    end
    
    # メタデータを展開する
    def inflate_meta_data(data)
      idx = 21
      compressed_len = get_meta_data_length(data)
      
      block_data = data.slice(idx, compressed_len)
      # zlib header : 78 9C
      if block_data.slice(0, 2) == "\x78\x9c".force_encoding('ASCII-8BIT') then
        inflate_data = Zlib::Inflate.inflate(block_data)
        return inflate_data
      else
        raise "ERROR: zlib header invalide (#{block_data.slice(0, 2)} != \"\x78\x9c\")"
      end
    end
    
    # メタデータをマスクする
    def mask_meta_data(meta_data)
      data = meta_data.clone
      # マスク対象のメタデータキー文字列（必要に応じて変更）
      keys = %w()
      keys.each do |key|
        search_key = key.force_encoding('ASCII-8BIT') + "\x10\x00\x00\x08".force_encoding('ASCII-8BIT')
        idx = 0
        while (idx = data.index(search_key, idx)) do
          idx += (key.bytesize + 4)
          len = data.slice(idx, 4).unpack("I")[0]
          idx += 4
          data[idx, len] = "\x00".force_encoding('ASCII-8BIT') * len
          idx += len
        end
      end
      data
    end
  end  
end
