package com.sirolf2009.gladiator.chat

import com.github.jnidzwetzki.bitfinex.v2.BitfinexApiBroker
import com.github.jnidzwetzki.bitfinex.v2.entity.BitfinexCurrencyPair
import com.github.jnidzwetzki.bitfinex.v2.entity.Position
import com.github.jnidzwetzki.bitfinex.v2.entity.symbol.BitfinexTickerSymbol
import com.google.common.util.concurrent.AtomicDouble
import com.google.gson.Gson
import com.google.gson.JsonArray
import java.io.File
import java.math.BigDecimal
import java.net.URL
import java.nio.charset.Charset
import java.nio.file.NoSuchFileException
import java.text.DecimalFormat
import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.TimerTask
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.apache.commons.io.IOUtils
import org.apache.logging.log4j.LogManager
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.telegram.telegrambots.ApiContextInitializer
import org.telegram.telegrambots.TelegramBotsApi
import org.telegram.telegrambots.api.methods.send.SendMessage
import org.telegram.telegrambots.api.objects.Update
import org.telegram.telegrambots.bots.TelegramLongPollingBot
import java.text.NumberFormat

class GladiatorTradingChatBot extends TelegramLongPollingBot {

	static val log = LogManager.getLogger()
	static val scheduler = Executors.newScheduledThreadPool(1)
	val Configuration configuration
	val BitfinexApiBroker bitfinexApiBroker
	val AtomicDouble currentPrice = new AtomicDouble(1)
	val moneyFormat = NumberFormat.getCurrencyInstance()
	
	/*
	 * //private floris chat
	 * Update{
	 *  updateId=135396503, 
	 *  message=Message{
	 *   messageId=499, from=User{id=301492746, firstName='Floris', lastName='Thijssen', userName='sirolf2009', languageCode='en'}, 
	 *   date=1556023912, 
	 *   chat=Chat{id=301492746, type='private', title='null', firstName='Floris', lastName='Thijssen', userName='sirolf2009', allMembersAreAdministrators=null, photo=null, description='null', inviteLink='null'
	 *  }, 
	 *  forwardFrom=null, 
	 *  forwardFromChat=null, 
	 *  forwardDate=null, 
	 *  text='/position', 
	 *  entities=[
	 *   MessageEntity{type='bot_command', offset=0, length=9, url=null, user=null}
	 *  ], 
	 *  audio=null, document=null, photo=null, sticker=null, video=null, contact=null, location=null, venue=null, pinnedMessage=null, newChatMembers=null, leftChatMember=null, newChatTitle='null', newChatPhoto=null, deleteChatPhoto=null, groupchatCreated=null, replyToMessage=null, voice=null, caption='null', superGroupCreated=null, channelChatCreated=null, migrateToChatId=null, migrateFromChatId=null, editDate=null, game=null, forwardFromMessageId=null, invoice=null, successfulPayment=null, videoNote=null}, inlineQuery=null, chosenInlineQuery=null, callbackQuery=null, editedMessage=null, channelPost=null, editedChannelPost=null, shippingQuery=null, preCheckoutQuery=null
	 * }
	 */
	 
	 /*
	  * //gladiator group chat
	  * Update{
	  *  updateId=135396505,
	  *  message=Message{
	  *   messageId=503, 
	  *   from=User{id=301492746, firstName='Floris', lastName='Thijssen', userName='sirolf2009', languageCode='en'},
	  *   date=1556025117,
	  *   chat=Chat{id=-317274639, type='group', title='Gladiator', firstName='null', lastName='null', userName='null', allMembersAreAdministrators=false, photo=null, description='null', inviteLink='null'}, forwardFrom=null, forwardFromChat=null, forwardDate=null, text='/position', entities=[MessageEntity{type='bot_command', offset=0, length=9, url=null, user=null}], audio=null, document=null, photo=null, sticker=null, video=null, contact=null, location=null, venue=null, pinnedMessage=null, newChatMembers=null, leftChatMember=null, newChatTitle='null', newChatPhoto=null, deleteChatPhoto=null, groupchatCreated=null, replyToMessage=null, voice=null, caption='null', superGroupCreated=null, channelChatCreated=null, migrateToChatId=null, migrateFromChatId=null, editDate=null, game=null, forwardFromMessageId=null, invoice=null, successfulPayment=null, videoNote=null}, inlineQuery=null, chosenInlineQuery=null, callbackQuery=null, editedMessage=null, channelPost=null, editedChannelPost=null, shippingQuery=null, preCheckoutQuery=null}
	  */

	new(File config) {
		try {
			configuration = ConfigurationJsonDeserializer.read(config)
		} catch(NoSuchFileException e) {
			System.err.println("Generating new config file")
			config.getParentFile().mkdirs()
			ConfigurationJsonDeserializer.write(new Configuration("", "", "", ""), config)
			System.err.println("Generated new config file @ " + config)
			throw e
		}
		bitfinexApiBroker = new BitfinexApiBroker(configuration.bfxKey, configuration.bfxSecret)
		bitfinexApiBroker.connect()
		val symbol = new BitfinexTickerSymbol(BitfinexCurrencyPair.BTC_USD)
		bitfinexApiBroker.getQuoteManager().registerTickCallback(symbol) [ s, tick |
			currentPrice.set(tick.getLastPrice().doubleValue())
		]
		bitfinexApiBroker.getQuoteManager().subscribeTicker(symbol)
		
		scheduleMorningMessage()
	}

	def scheduleMorningMessage() {
		val ZonedDateTime now = ZonedDateTime.now(ZoneId.of("Europe/Amsterdam"))

		var ZonedDateTime nextRun = now.withHour(6).withMinute(30).withSecond(0)
		if(now.compareTo(nextRun) > 0)
			nextRun = nextRun.plusDays(1)

		val duration = Duration.between(now, nextRun)
		val initalDelay = duration.getSeconds()
		
		log.info("Scheduling morning message in "+duration)

		scheduler.scheduleAtFixedRate(new MorningMessageTask(this, -317274639l), initalDelay, TimeUnit.DAYS.toSeconds(1), TimeUnit.SECONDS)
	}

	override getBotToken() {
		return configuration.botToken
	}

	override getBotUsername() {
		return configuration.botUsername
	}

	override onUpdateReceived(Update update) {
		log.info(update)
		if(update.hasMessage() && update.getMessage().hasText()) {
			if(update.getMessage().getText().equals("/position")) {
				sendPositionsTo(update.getMessage().getChatId())
			}
		}
	}

	def sendPositionsTo(Long chatID) {
		val wallets = bitfinexApiBroker.getWalletManager().getWallets()
		val usdBalance = wallets.findFirst[getCurreny().equals("USD")].getBalance().doubleValue()
		val btcBalance = wallets.findFirst[getCurreny().equals("BTC")].getBalance().doubleValue() * currentPrice.get()
		val positions = bitfinexApiBroker.getPositionManager().getPositions()
		val profit = positions.map[getProfit(getPrice())].reduce[a,b|a+b]
		
		positions.map [
			val price = getPrice()
			'''
			«getCurreny().getCurrency1()» «getCurreny().getCurrency2()»
			«if(isShort()) "Short" else "Long"» «getAmount().abs()» @ «moneyFormat.format(getBasePrice())»
			Profit: «moneyFormat.format(getProfit(price))»    Current Price: «moneyFormat.format(price)»'''
		].map [
			new SendMessage().setChatId(chatID).setText(it)
		].forEach [
			sendMessage(it)
		]
		
		sendMessage(new SendMessage().setChatId(chatID).setText('''
		Total Balance: «moneyFormat.format(usdBalance + btcBalance)»
		Total Profit: «moneyFormat.format(profit)»
		NAV: «moneyFormat.format(usdBalance + btcBalance + profit)»'''))
	}

	def getPrice(Position position) {
		return position.getCurreny().getPrice()
	}

	def getPrice(BitfinexCurrencyPair pair) {
		if(pair.equals(BitfinexCurrencyPair.BTC_USD)) {
			return currentPrice.get()
		} else {
			val string = IOUtils.toString(new URL('''https://api.bitfinex.com/v2/ticker/t«pair.getCurrency1()»«pair.getCurrency2()»'''), Charset.defaultCharset)
			new Gson().fromJson(string, JsonArray).get(6).getAsDouble()
		}
	}

	def getProfit(Position position) {
		return getProfit(position, position.getPrice())
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

	@FinalFieldsConstructor static class MorningMessageTask extends TimerTask {

		val GladiatorTradingChatBot bot
		val Long chatID

		override run() {
			bot.sendPositionsTo(chatID)
		}

	}

}
