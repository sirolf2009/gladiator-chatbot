package com.sirolf2009.gladiator.chat

import com.google.gson.GsonBuilder
import com.google.gson.reflect.TypeToken
import com.sirolf2009.util.GSonDTO
import java.io.File
import java.nio.file.Files
import java.util.ArrayList
import java.util.List
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors

class ShareManager {
	
	val shareFile = new File("shares")
	val gson = new GsonBuilder().registerTypeAdapter(ShareHolder, new ShareHolderJsonDeserializer()).create()
	
	new() {
		if(!shareFile.exists()) {
			save(#[])
		}
	}
	
	def set(String shareHolderName, double share, double invested, double withdrawn) {
		val shareHolders = read()
		val shareHolder = shareHolders.stream().filter[name.equals(shareHolderName)].findFirst()
		val newShareHolders = new ArrayList(shareHolders)
		if(shareHolder.isPresent()) {
			newShareHolders.remove(shareHolder)
		}
		newShareHolders.add(new ShareHolder(shareHolderName, share, invested, withdrawn))
		newShareHolders.save()
	}
	
	def List<ShareHolder> read() {
		(gson.fromJson(Files.readAllLines(shareFile.toPath()).join("\n"), new TypeToken<List<ShareHolder>>{}.getType()) as List<ShareHolder>).sortBy[getShare()].reverse()
	}
	
	def save(List<ShareHolder> shareHolders) {
		Files.write(shareFile.toPath(), gson.toJson(shareHolders).getBytes())
	}
	
	@FinalFieldsConstructor @Accessors @GSonDTO static class ShareHolder {
		val String name
		val double share
		val double invested
		val double withdrawn
		
		def getShareWorth(double currentNAV) {
			return currentNAV / 100 * share
		}
		
		def getPercentageReturn(double currentNAV) {
			return invested / (getShareWorth(currentNAV) + withdrawn) * 100
		}
	} 
	
}