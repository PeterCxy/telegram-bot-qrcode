pkg = require '../package.json'
{korubaku} = require 'korubaku'
JPEGDecoder = require 'jpg-stream/decoder'
QrCodeReader = require 'qrcode-reader'
concat = require 'concat-frames'
request = require 'request'

exports.name = 'qrcode'
exports.desc = 'QR encoder and decoder'

exports.setup = (telegram, store, server) ->
	[
			cmd: 'qrdecode'
			desc: 'Decode QR code'
			num: 0
			act: (msg) ->
				telegram.sendMessage msg.chat.id, 'Now send me the picture you want to decode'
				server.grabInput msg.chat.id, msg.from.id, pkg.name, 'decode'
	]

exports.input = (cmd, msg, telegram, store, server) ->
	if cmd is 'decode'
		decode msg, telegram, server

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
							telegram.sendMessage msg.chat.id, result
						try
							qr.decode frames[0], frames[0].pixels
						catch e
							console.log e
							telegram.sendMessage msg.chat.id, 'Decode failure.'
				))
		else
			telegram.sendMessage msg.chat.id, 'Decode failure. File size may have exceeded the maximum of 200K (Telegram-compressed)'
	
		server.releaseInput msg.chat.id, msg.from.id
