class LinebotsController < ApplicationController
  require 'line/bot'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      return head :bad_request
    end
    
    client.parse_events_from(body).each do |event|
      if event.type == Line::Bot::Event::MessageType::Text
        input = event.message['text']
        message = search_and_create_message(input)
        client.reply_message(event['replyToken'], message)
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_BOT_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_BOT_CHANNEL_TOKEN']
    end
  end

  def search_and_create_message(input)
    items = []
    max_hit_items = 3 #商品取得最大値

    RakutenWebService.configure do |c|
      c.application_id = ENV['RAKUTEN_APPID']
      c.affiliate_id = ENV['RAKUTEN_AFID']
    end

    res = RakutenWebService::Ichiba::Item.search(keyword: input, hits: max_hit_items, imageFlag: 1)
    items = res.map{|item| item}
    make_reply_content(items)
  end

  def make_reply_content(items)
    {
      "type": 'flex',
      "altText": '商品情報を取得',
      "contents":
      {
        "type": 'carousel',
        "contents": [
          make_part(items[0]),
          make_part(items[1]),
          make_part(items[2])
        ]
      }
    }
  end

  def make_part(item)
    title = item['itemName'].slice(0..20) + '...'
    price = item['itemPrice'].to_s + '円'
    url = item['itemUrl']
    image = item['mediumImageUrls'].first
    {
      "type": "bubble",
      "hero": {
        "type": "image",
        "size": "full",
        "aspectRatio": "20:13",
        "aspectMode": "cover",
        "url": image
      },
      "body":
      {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "text",
            "text": title,
            "wrap": true,
            "weight": "bold",
            "size": "lg"
          },
          {
            "type": "box",
            "layout": "baseline",
            "contents": [
              {
                "type": "text",
                "text": price,
                "wrap": true,
                "weight": "bold",
                "flex": 0
              }
            ]
          }
        ]
      },
      "footer": {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "button",
            "style": "primary",
            "action": {
              "type": "uri",
              "label": "楽天市場商品ページへ",
              "uri": url
            }
          }
        ]
      }
    }
  end
end
