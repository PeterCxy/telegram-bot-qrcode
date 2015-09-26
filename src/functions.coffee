pkg = require '../package.json'
{korubaku} = require 'korubaku'
JPEGDecoder = require 'jpg-stream/decoder'
QrCodeReader = require 'qrcode-reader'
QRCode = require 'qrcode'
concat = require 'concat-frames'
request = require 'request'
fs = require 'fs'

exports.name = 'qrcode'
exports.desc = 'QR encoder and decoder'

exports.setup = (telegram, store, server) ->
	[
			cmd: 'qrencode'
			desc: 'Encode text into QR code'
			typing: yes
			args: '<text>'
			num: -1
			act: (msg, args) ->
				if !msg.reply_to_message?
					str = args.join(' ').trim()
					if str isnt ''
						console.log str
						encode str, msg, telegram
				else
					encode msg.reply_to_message.text, msg, telegram
		,
			cmd: 'qrdecode'
			desc: 'Decode QR code'
			num: 0
			act: (msg) ->
				if !msg.reply_to_message?
					telegram.sendMessage msg.chat.id, 'Now send me the picture you want to decode', msg.message_id
					server.grabInput msg.chat.id, msg.from.id, pkg.name, 'decode'
				else
					decode msg.reply_to_message, telegram, server
	]

exports.input = (cmd, msg, telegram, store, server) ->
	if cmd is 'decode'
		decode msg, telegram, server

encode = (text, msg, telegram) ->
	file = "/tmp/qrcode_#{Date.now()}.png"
		
	try
		# QRCode will fail with Korubaku
		QRCode.save file, text, (err, written) ->
			console.log "written = #{written}"

			if !err?
				stream = fs.createReadStream file
				telegram.sendPhoto msg.chat.id, stream, msg.message_id, (err) ->
					fs.unlink file
			else
				telegram.sendMessage msg.chat.id, 'Encode failure', msg.message_id
	catch e
		console.log e


decode = (msg, telegram, server) ->
	korubaku (ko) ->
		if !msg.photo? or msg.photo.length is 0
			telegram.sendMessage msg.chat.id, 'Please send me a picture.', msg.message_id
			return
		
		yield telegram.sendChatAction msg.chat.id, 'typing', ko.default()
		id = msg.photo[msg.photo.length - 1].file_id
		[error, file] = yield telegram.getFile id, ko.raw()

		if !error? and file? and file.file_size? and file.file_size <= 200 * 1024
			console.log file.file_path
			url = telegram.getFileUrl file.file_path
			request(url)
				.pipe(new JPEGDecoder)
				.pipe(concat((frames) ->
					if frames.length >= 1
						qr = new QrCodeReader
						qr.callback = (result) ->
							telegram.sendMessage msg.chat.id, result, msg.message_id
						try
							qr.decode frames[0], frames[0].pixels
						catch e
							console.log e
							telegram.sendMessage msg.chat.id, 'Decode failure.', msg.message_id
				))
		else
			telegram.sendMessage msg.chat.id, 'Decode failure. File size may have exceeded the maximum of 200K (Telegram-compressed)', msg.message_id
	
		server.releaseInput msg.chat.id, msg.from.id
