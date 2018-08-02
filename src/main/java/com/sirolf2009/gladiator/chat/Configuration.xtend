package com.sirolf2009.gladiator.chat

import com.sirolf2009.util.GSonDTO
import org.eclipse.xtend.lib.annotations.Data

@Data @GSonDTO class Configuration {
	
	String botToken
	String botUsername
	String bfxKey
	String bfxSecret
	
}