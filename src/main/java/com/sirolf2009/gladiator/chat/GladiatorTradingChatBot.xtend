package com.sirolf2009.gladiator.chat

import com.github.jnidzwetzki.bitfinex.v2.BitfinexApiBroker
import com.github.jnidzwetzki.bitfinex.v2.entity.BitfinexCurrencyPair
import com.github.jnidzwetzki.bitfinex.v2.entity.Position
import com.github.jnidzwetzki.bitfinex.v2.entity.symbol.BitfinexTickerSymbol
import com.google.common.util.concurrent.AtomicDouble
import java.math.BigDecimal
import org.telegram.telegrambots.ApiContextInitializer
import org.telegram.telegrambots.TelegramBotsApi
import org.telegram.telegrambots.api.methods.send.SendMessage
import org.telegram.telegrambots.api.objects.Update
import org.telegram.telegrambots.bots.TelegramLongPollingBot
import org.telegram.telegrambots.exceptions.TelegramApiException
import java.text.DecimalFormat
import java.io.File
import java.nio.file.NoSuchFileException

class GladiatorTradingChatBot extends TelegramLongPollingBot {

	val Configuration configuration
	val BitfinexApiBroker bitfinexApiBroker
	val AtomicDouble currentPrice = new AtomicDouble(1)
	val decimalFormat = new DecimalFormat("0.##")

	new(File config) {
		try {
		configuration = ConfigurationJsonDeserializer.read(config)
		println(configuration)
		} catch(NoSuchFileException e) {
			System.err.println("Generating new config file")
			config.getParentFile().mkdirs()
			ConfigurationJsonDeserializer.write(new Configuration("", "", "", ""), config)
			System.err.println("Generated new config file @ "+config)
			throw e
		}
		bitfinexApiBroker = new BitfinexApiBroker(configuration.bfxKey, configuration.bfxSecret)
		bitfinexApiBroker.connect()
		val symbol = new BitfinexTickerSymbol(BitfinexCurrencyPair.BTC_USD)
		bitfinexApiBroker.getQuoteManager().registerTickCallback(symbol) [s, tick|
			currentPrice.set(tick.getLastPrice().doubleValue())
		]
		bitfinexApiBroker.getQuoteManager().subscribeTicker(symbol)
	}

	override getBotToken() {
		return configuration.botToken
	}

	override getBotUsername() {
		return configuration.botUsername
	}

	override onUpdateReceived(Update update) {
		if(update.hasMessage() && update.getMessage().hasText()) {
			if(update.getMessage().getText().equals("/position")) {
				val positions = bitfinexApiBroker.getPositionManager().getPositions().map[
					'''
					«if(isShort()) "Short" else "Long"» «getAmount().abs()» @ $«decimalFormat.format(getBasePrice())»
					Profit: $«decimalFormat.format(getProfit())»    Current Price: $«decimalFormat.format(currentPrice.get())»'''
				].join("\n")
				
				val message = new SendMessage().setChatId(update.getMessage().getChatId()).setText(positions);
				try {
					sendMessage(message)
				} catch(TelegramApiException e) {
					e.printStackTrace();
				}
			}
		}
	}
	
	def getProfit(Position position) {
		return getProfit(position, currentPrice.get())
	}
	
	def static getProfit(Position position, double priceNow) {
		if(position.isShort()) {
			return (position.getBasePrice().doubleValue() - priceNow) * -position.getAmount().doubleValue()
		} else {
			return (priceNow - position.getBasePrice().doubleValue()) * position.getAmount().doubleValue()
		}
	}
	
	def static isShort(Position position) {
		return position.getAmount().max(BigDecimal.ZERO).equals(BigDecimal.ZERO)		
	}

	def static void main(String[] args) {
		ApiContextInitializer.init()
		val botsApi = new TelegramBotsApi()
		botsApi.registerBot(new GladiatorTradingChatBot(new File(System.getProperty("user.home"), ".gladiator/chat-config.json")))
	}

}
