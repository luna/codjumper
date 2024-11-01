#include common_scripts\utility;
#include maps\mp\gametypes\_hud_util;
#include maps\mp\gametypes\koth;
#include maps\mp\gametypes\sab;

init()
{
	precacheShader("reticle_flechette"); // Precache the reticle shader for Forge

	// Replaced by the build script
	level.VERSION = "__VERSION__";

	level.THEME_COLOR = (0, 0, 1);

	level.SELECTED_PREFIX = "^2-->^7 ";

	initForgeModels();

	// sab_bomb is always on the ground in the middle of the map
    level.MAP_CENTER_GROUND_ORIGIN = getent("sab_bomb", "targetname").origin;

    setAllSpawnPointsToOrigin(level.MAP_CENTER_GROUND_ORIGIN);

	deleteUselessEntities();

	level.hardcoreMode = true; // Force hardcore mode

	gametype = level.gametype;

	setDvar("scr_" + gametype + "_scorelimit", 0);
	setDvar("scr_" + gametype + "_timelimit", 0);
	setDvar("scr_" + gametype + "_playerrespawndelay", 0);
	setDvar("scr_" + gametype + "_numlives", 0);
	setDvar("scr_" + gametype + "_roundlimit", 0);

	setDvar("ui_hud_showobjicons", 0);		// Hide objective icons from HUD and map

	setDvar("scr_game_perks", 0);			// Remove perks
	setDvar("scr_showperksonspawn", 0);		// Remove perks icons shown on spawn
	setDvar("scr_game_hardpoints", 0);		// Remove killstreaks

	setDvar("player_sprintUnlimited", 1);
	setDvar("jump_slowdownEnable", 0);

	// Remove fall damage
	setDvar("bg_fallDamageMaxHeight", 9999);
	setDvar("bg_fallDamageMinHeight", 9998);

	// Prevent bots from moving
	setDvar("sv_botsRandomInput", 0);
	setDvar("sv_botsPressAttackBtn", 0);

	setDvar("userinfo", "L"); // prevent people from freezing consoles via userinfo command

	level thread onPlayerConnect();
}

onPlayerConnect()
{
	for (;;)
	{
		level waittill("connecting", player);

		// Don't setup bot players
		if ( isDefined( player.pers["isBot"] ) )
			continue;

		// JumpCrouch / binds helper
		player setClientDvar("activeaction", "vstr VSTR_LEAN_DISABLED;");
		player setClientDvar("VSTR_LEAN_ENABLED", "bind BUTTON_A vstr BUTTON_A_ACTION;bind DPAD_DOWN +actionslot 3; bind DPAD_LEFT +leanleft; bind DPAD_RIGHT +leanright");
		player setClientDvar("VSTR_LEAN_DISABLED", "bind BUTTON_A vstr BUTTON_A_ACTION;bind DPAD_DOWN +actionslot 2; bind DPAD_LEFT +actionslot 3; bind DPAD_RIGHT +actionslot 4");
		player setClientDvar("BUTTON_A_ACTION", "+gostand;-gostand");

		player setupPlayer();
		player thread onPlayerSpawned();
	}
}

onPlayerSpawned()
{
	self endon("disconnect");
	for(;;)
	{
		self waittill("spawned_player");

		self.cj["settings"]["forge"] = false;

		self thread ammoCheck();
		self thread setupLoadout();
		self thread watchMeleeButtonPressed();
		self thread watchSecondaryOffhandButtonPressed();
		self thread watchFragButtonPressed();
		self thread updateSpeedometerHudElem();
		self thread watchDPAD_UP();
		self thread watchUseButtonPressed();
		self thread initMenu();
		self resetFOV();
	}
}

resetFOV()
{
	if(isdefined(self.cj["settings"]["cg_fov"]))
		self setClientDvar("cg_fov", self.cj["settings"]["cg_fov"]);
}

setupPlayer()
{
	self.cj = [];
	self.cj["saves"] = [];
	self.cj["bots"] = [];
	self.cj["botnumber"] = 0;
	self.cj["clones"] = [];
	self.cj["maxbots"] = 4;
	self.cj["settings"] = [];
	self.cj["settings"]["deserteagle_choice"] = "deserteaglegold_mp";
	self.cj["settings"]["specialty_fastreload_enable"] = true;
	self.cj["settings"]["rpg_switch_enabled"] = false;
	self.cj["settings"]["rpg_switched"] = false;

	// Remove unlocalized errors
	self setClientDvars("loc_warnings", 0, "loc_warningsAsErrors", 0, "cg_errordecay", 1, "con_errormessagetime", 0, "uiscript_debug", 0);

	// Set team names
	self setClientDvars("g_TeamName_Allies", "Jumpers", "g_TeamName_Axis", "Bots");

	self setClientDvars("cg_overheadRankSize", 0, "cg_overheadIconSize", 0);		// Remove overhead rank and icon

	self setClientDvar("nightVisionDisableEffects", 1);	// Remove nightvision fx

	// Remove objective waypoints on screen
	self setClientDvar("waypointIconWidth", 0.1);
	self setClientDvar("waypointIconHeight", 0.1);
	self setClientDvar("waypointOffscreenPointerWidth", 0.1);
	self setClientDvar("waypointOffscreenPointerHeight", 0.1);

	// Disable FX
	self setClientDvars("fx_enable", 0, "fx_marks", 0, "fx_marks_ents", 0, "fx_marks_smodels", 0);

	self setClientDvar("clanname", "");					// Remove clan tag
	self setClientDvar("motd", "CodJumper");

	self setClientDvar("aim_automelee_range", 0);		// Remove melee lunge

	// Disable autoaim for enemy players
	self setClientDvars("aim_slowdown_enabled", 0, "aim_lockon_enabled", 0);

	// Don't show enemy player names
	self setClientDvars("cg_enemyNameFadeIn", 0, "cg_enemyNameFadeOut", 0);

	// Always show enemies on the map but hide compass, can see enemy positions when pressing start
	self setClientDvars("g_compassShowEnemies", 1, "compassSize", 0.001);

	self setClientDvar("cg_scoreboardPingText", 1);

	self setClientDvar("cg_chatHeight", 0); // prevent people from freezing consoles via say command

	// look straight up
	self setclientdvar("player_view_pitch_up", 89.9);

	// Remove glow color applied to the mode and map name strings on the connect screen
	self setClientDvar("ui_ConnectScreenTextGlowColor", 0);

	self setClientDvar("cg_descriptiveText", 0);			// Remove spectator button icons and text
	self setClientDvar("player_spectateSpeedScale", 1.5);	// Faster movement in spectator/ufo
}

initMenuOpts()
{
	self addMenu("main", "CodJumper " + level.VERSION, undefined);

	is_host = self GetEntityNumber() == 0;

	// Host submenu
	if(is_host)
	{
		self addOpt("main", "Global settings", ::subMenu, "host_menu");
		self addMenu("host_menu", "Global settings", "main");
		self addOpt("host_menu", "Toggle jump_slowdownEnable", ::toggleJumpSlowdown);
		self addOpt("host_menu", "Toggle Old School Mode", ::toggleOldschool);

		if(getDvarInt("ui_allow_teamchange") == 1)
		{
			// Map selector
			self addOpt("main", "Select map", ::subMenu, "host_menu_maps");
			self addMenu("host_menu_maps", "Select map", "main");
			self addOpt("host_menu_maps", "Ambush", ::changeMap, "mp_convoy");
			self addOpt("host_menu_maps", "Backlot", ::changeMap, "mp_backlot");
			self addOpt("host_menu_maps", "Bloc", ::changeMap, "mp_bloc");
			self addOpt("host_menu_maps", "Bog", ::changeMap, "mp_bog");
			self addOpt("host_menu_maps", "Broadcast", ::changeMap, "mp_broadcast");
			self addOpt("host_menu_maps", "Chinatown", ::changeMap, "mp_carentan");
			self addOpt("host_menu_maps", "Countdown", ::changeMap, "mp_countdown");
			self addOpt("host_menu_maps", "Crash", ::changeMap, "mp_crash");
			self addOpt("host_menu_maps", "Creek", ::changeMap, "mp_creek");
			self addOpt("host_menu_maps", "Crossfire", ::changeMap, "mp_crossfire");
			self addOpt("host_menu_maps", "District", ::changeMap, "mp_citystreets");
			self addOpt("host_menu_maps", "Downpour", ::changeMap, "mp_farm");
			self addOpt("host_menu_maps", "Killhouse", ::changeMap, "mp_killhouse");
			self addOpt("host_menu_maps", "Overgrown", ::changeMap, "mp_overgrown");
			self addOpt("host_menu_maps", "Pipeline", ::changeMap, "mp_pipeline");
			self addOpt("host_menu_maps", "Shipment", ::changeMap, "mp_shipment");
			self addOpt("host_menu_maps", "Showdown", ::changeMap, "mp_showdown");
			self addOpt("host_menu_maps", "Strike", ::changeMap, "mp_strike");
			self addOpt("host_menu_maps", "Vacant", ::changeMap, "mp_vacant");
			self addOpt("host_menu_maps", "Wet Work", ::changeMap, "mp_cargoship");
			self addOpt("host_menu_maps", "Winter Crash", ::changeMap, "mp_crash_snow");
		}
	}

	self addOpt("main", "Game Objects Menu", ::subMenu, "menu_game_objects");

	self addMenu("menu_game_objects", "Game Objects Menu", "main");
	self addOpt("menu_game_objects", "Spawn Object", ::subMenu, "menu_game_objects_spawn");
	self addMenu("menu_game_objects_spawn", "Spawn Object", "menu_game_objects");

	// create a submenu for each model type
	modelnames = getarraykeys(level.FORGE_MODELS);
	for (i = 0; i < modelnames.size; i++)
	{
		modelName = modelnames[i];
		count = level.FORGE_MODELS[modelName].size;
		if (count == 0) // skip empty model types
			continue;
		menuLabel = modelName + " " + " (" + count + ")";
		menuKey = "menu_game_objects_select_" + modelName;
		self addOpt("menu_game_objects_spawn", menuLabel, ::subMenu, menuKey);
		self addMenu(menuKey, menuLabel, "menu_game_objects_spawn");

		for (j = 0; j < level.FORGE_MODELS[modelName].size; j++)
		{
			modelEnt = level.FORGE_MODELS[modelName][j];
			menuLabel = modelName + " " + (j + 1);
			self addOpt(menuKey, menuLabel, ::spawnGameObject, modelEnt);
		}
	}

	if(is_host)
	{
		self addOpt("menu_game_objects", "Show/Hide Domination", ::show_hide_by_script_gameobjectname, "dom");
		self addOpt("menu_game_objects", "Show/Hide HQ", ::show_hide_by_script_gameobjectname, "hq");
		self addOpt("menu_game_objects", "Show/Hide Sab", ::show_hide_by_script_gameobjectname, "sab");
		self addOpt("menu_game_objects", "Show/Hide SD", ::show_hide_by_script_gameobjectname, "bombzone");
		self addOpt("menu_game_objects", "^1Reset All!^7", ::resetAllGameObjects);
	}

	// Loadout submenu
	self addOpt("main", "Loadout Menu", ::subMenu, "loadout_menu");
	self addMenu("loadout_menu", "Loadout Menu", "main");
	self addOpt("loadout_menu", "Switch Desert Eagle", ::switchDesertEagle);
	self addOpt("loadout_menu", "Sleight of Hand", ::toggleFastReload);
	self addOpt("loadout_menu", "RPG Switch", ::toggleRPGSwitch);

	self addOpt("main", "3rd Person", ::toggleThirdPerson);
	self addOpt("main", "cg_drawgun", ::toggleShowGun);
	self addOpt("main", "Player names", ::togglePlayerNames);
	self addOpt("main", "Gun bob", ::toggleGunBob);
	self addOpt("main", "Spectator buttons", ::toggleSpectatorButtons);
	self addOpt("main", "Speed + Height meter", ::toggleSpeedometerHudElem);
	self addOpt("main", "Jump Crouch", ::toggleJumpCrouch);
	self addOpt("main", "Lean ON", ::enableLeanBinds);
	self addOpt("main", "Lean OFF", ::disableLeanBinds);
	self addOpt("main", "FOV", ::toggleFOV);
	self addOpt("main", "r_zfar", ::toggle_r_zfar);
	self addOpt("main", "Fog", ::toggle_r_fog);
	self addOpt("main", "Depth of field", ::toggle_r_dof_enable);
	self addOpt("main", "Look straight down", ::toggle_look_straight_down);

	// Bot submenu
	self addOpt("main", "Bot Menu", ::subMenu, "bot_menu");
	self addMenu("bot_menu", "Bot Menu", "main");
	for (i = 0; i < self.cj["maxbots"]; i++)
	{
		text = "";
		if(self.cj["botnumber"] == i)
			text += level.SELECTED_PREFIX;

		text += "Set active bot " + (i + 1);
		// If bot is already spawned display its origin
		// useful to record good bot positions
		if(isplayer(self.cj["bots"][i]))
		{
			origin = self.cj["bots"][i].origin;
			origin = (int(origin[0]), int(origin[1]), int(origin[2]));
			text += (" " + origin);
		}

		self addOpt("bot_menu", text, ::setSelectedBot, i);
	}
	self addOpt("bot_menu", "Spawn Floating Bot", ::spawnFloatingBot);
	if(is_host)
		self addOpt("bot_menu", "Kick All Bots", ::kickAllBots);

	// Clone submenu
	self addOpt("main", "Clone Menu", ::subMenu, "clone_menu");
	self addMenu("clone_menu", "Clone Menu", "main");
	self addOpt("clone_menu", "Spawn Clone", ::addClone);
	self addOpt("clone_menu", "Remove Clones", ::deleteClones);

	#if defined(SYSTEM_XENON)
		// Enhanced submenu
		if(is_host)
		{
			self addOpt("main", "Enhanced Menu", ::subMenu, "enhanced_menu");	// Add to main menu


			self addMenu("enhanced_menu", "Enhanced Menu", "main");
			self addOpt("enhanced_menu", "Barrier Menu", ::subMenu, "barrier_menu");
			self addOpt("enhanced_menu", "Bot Action Menu", ::subMenu, "bot_action_menu");

			// Barrier submenu
			self addMenu("barrier_menu", "Barrier Menu", "enhanced_menu");
			self addOpt("barrier_menu", "Remove All Barriers", ::removeBarriersOverHeight, 0);
			self addOpt("barrier_menu", "Remove Barriers > 100 Height", ::removeBarriersOverHeight, 100);
			self addOpt("barrier_menu", "Remove Barriers > 500 Height", ::removeBarriersOverHeight, 500);
			self addOpt("barrier_menu", "Remove Barriers > 1000 Height", ::removeBarriersOverHeight, 1000);
			self addOpt("barrier_menu", "Remove Barriers > 1500 Height", ::removeBarriersOverHeight, 1500);
			self addOpt("barrier_menu", "Restore Barriers", ::restoreBarriers);

			// Bot Action submenu
			self addMenu("bot_action_menu", "Bot Action Menu", "enhanced_menu");
			self addOpt("bot_action_menu", "Auto Mantle ON/OFF", ::toggleAutoMantle);
			self addOpt("bot_action_menu", "Trigger Distance UP", ::modifyTriggerDistance, 10);
			self addOpt("bot_action_menu", "Trigger Distance DOWN", ::modifyTriggerDistance, -10);
		}
	#endif
}

initMenu()
{
	self endon("end_respawn");
	self endon("disconnect");

	level.SCROLL_TIME_SECONDS = 0.15;

	self.inMenu = undefined;

	self.currentMenu = "main";
	self.menuCurs = 0;

	for(;;)
	{
		if(isDefined(self.inMenu))
		{
			// Menu UP/DOWN
			if(self attackButtonPressed() || self adsButtonPressed())
			{
				self.menuCurs += self attackButtonPressed();
				self.menuCurs -= self adsButtonPressed();

				if(self.menuCurs > self.menuAction[self.currentMenu].opt.size - 1)
					self.menuCurs = 0;
				else if(self.menuCurs < 0)
					self.menuCurs = self.menuAction[self.currentMenu].opt.size - 1;

				self.scrollBar moveOverTime(level.SCROLL_TIME_SECONDS);
				self.scrollBar.y = ((self.menuCurs * 17.98) + ((self.menuText.y + 1) - (17.98 / 2)));

				wait level.SCROLL_TIME_SECONDS;
			}

			// MENU SELECT
			if(self useButtonPressed())
			{
				self thread [[self.menuAction[self.currentMenu].func[self.menuCurs]]](self.menuAction[self.currentMenu].inp[self.menuCurs]);
				wait .2;
			}

			// MENU CLOSE
			if(self meleeButtonPressed())
			{
				if(!isDefined(self.menuAction[self.currentMenu].parent))
				{
					self freezecontrols(false);
					self.inMenu = undefined;
					self.menuCurs = 0;

					self.instructionsBackground destroy();
					self.instructionsText destroy();
					self.openBox destroy();
					self.menuText destroy();
					self.scrollBar destroy();
					self.openText destroy();
				}
				// Go back
				else
					self subMenu(self.menuAction[self.currentMenu].parent);
			}
		}
		wait .05;
	}
}

openCJ()
{
	if(!isDefined(self.inMenu))
	{
		self freezecontrols(true);
		self.inMenu = true;

		self initMenuOpts();
		menuOpts = self.menuAction[self.currentMenu].opt.size;

		instructionsString = "Press [{+activate}] to select item\nPress [{+attack}] [{+speed_throw}] to navigate Menu\nPress [{+melee}] to go back";
		self.instructionsText = self createText("default", 1.5, "TOPLEFT", "LEFT", 10, -54 ,100 ,1, (0, 0, 0) ,instructionsString);
		self.instructionsBackground = self createRectangle("TOPLEFT", "LEFT", 5, -55, 200, 3*19, (0, 0, 0), "white", 4, (1/1.6));

		self.openBox = self createRectangle("TOP", "TOPRIGHT", -160, 10, 300, 445, (0, 0, 0), "white", 1, .7);
		self.openText = self createText("default", 1.5, "TOP", "TOPRIGHT", -160, 16, 2, 1, level.THEME_COLOR, self.menuAction[self.currentMenu].title);
		string = "";
		for(m = 0; m < menuOpts; m++)
			string+= self.menuAction[self.currentMenu].opt[m]+"\n";
		self.menuText = self createText("default", 1.5, "LEFT", "TOPRIGHT", -300, 60, 3, 1, undefined, string);
		self.scrollBar = self createRectangle("TOP", "TOPRIGHT", -160, ((self.menuCurs*17.98)+((self.menuText.y+1)-(17.98/2))), 300, 15, level.THEME_COLOR, "white", 2, .7);
	}
}

watchUseButtonPressed()
{
	self endon("disconnect");
	self endon("end_respawn");

	for(;;)
	{
		if(!self.inMenu && self UseButtonPressed())
		{
			catch_next = false;

			for(i=0; i<=0.5; i+=0.05)
			{
				if(catch_next && self UseButtonPressed() && !(self isMantling()))
				{
					wait 0.1;
					thread openCJ();
					break;
				}
				else if(!(self UseButtonPressed()))
					catch_next = true;

				wait 0.05;
			}
		}

		wait 0.05;
	}
}

subMenu(menu)
{
	self.menuCurs = 0;
	self.currentMenu = menu;
	self.scrollBar moveOverTime(.2);
	self.scrollBar.y = ((self.menuCurs*17.98)+((self.menuText.y+1)-(17.98/2)));

	self refreshMenu();

	wait .2;
}

refreshMenu()
{
	self.menuText destroy();
	self initMenuOpts();
	self.openText setText(self.menuAction[self.currentMenu].title);
	menuOpts = self.menuAction[self.currentMenu].opt.size;
	string = "";
	for(m = 0; m < menuOpts; m++)
		string+= self.menuAction[self.currentMenu].opt[m]+"\n";
	self.menuText = self createText("default", 1.5, "LEFT", "TOPRIGHT", -300, 60, 3, 1, undefined, string);
}

addMenu(menu, title, parent)
{
	if(!isDefined(self.menuAction))
		self.menuAction = [];
	self.menuAction[menu] = spawnStruct();
	self.menuAction[menu].title = title;
	self.menuAction[menu].parent = parent;
	self.menuAction[menu].opt = [];
	self.menuAction[menu].func = [];
	self.menuAction[menu].inp = [];
}

addOpt(menu, opt, func, inp)
{
	m = self.menuAction[menu].opt.size;
	self.menuAction[menu].opt[m] = opt;
	self.menuAction[menu].func[m] = func;
	self.menuAction[menu].inp[m] = inp;
}

createText(font, fontScale, align, relative, x, y, sort, alpha, glow, text)
{
	textElem = self createFontString(font, fontScale, self);
	textElem setPoint(align, relative, x, y);
	textElem.sort = sort;
	textElem.alpha = alpha;
	textElem.glowColor = glow;
	textElem.glowAlpha = 1;
	textElem setText(text);
	self thread destroyOnDeath(textElem);
	return textElem;
}

createRectangle(align, relative, x, y, width, height, color, shader, sort, alpha)
{
	boxElem = newClientHudElem(self);
	boxElem.elemType = "bar";

	boxElem.children = [];
	boxElem.sort = sort;
	boxElem.color = color;
	boxElem.alpha = alpha;
	boxElem setParent(level.uiParent);
	boxElem setShader(shader, width, height);
	boxElem setPoint(align, relative, x, y);

	self thread destroyOnDeath(boxElem);

	return boxElem;
}

destroyOnDeath(elem)
{
	self waittill_any("end_respawn", "disconnect");
	if(isDefined(elem.bar))
		elem destroyElem();
	else
		elem destroy();
}

ammoCheck()
{
	self endon("end_respawn");
	self endon("disconnect");
	level endon("game_ended");

	for (;;)
	{
		currentWeapon = self getCurrentWeapon();
		if (!self isMantling() && !self isOnLadder())
		{
			self giveMaxAmmo(currentWeapon);
		}
		wait 2;
	}
}

setupLoadout()
{
	self clearPerks();
	self takeAllWeapons();

	if(self.cj["settings"]["specialty_fastreload_enable"] == true)
	{
		self setPerk("specialty_fastreload");	// Give Sleight of Hand
	}

	self giveWeapon("rpg_mp");
	self SetActionSlot( 3, "weapon", "rpg_mp" );

	if(self.cj["settings"]["rpg_switch_enabled"] == true)
	{
		self thread rpgSwitch(); // thread again in case player switches teams/classes etc
	}

	deserteagle_choice = self.cj["settings"]["deserteagle_choice"];

	self giveWeapon(deserteagle_choice);
	wait 0.05;
	self switchToWeapon(deserteagle_choice);

	// Oldschool mode gets the default oldschool weapons
	if(getDvarInt("jump_height") == 64)
	{
		self takeWeapon(deserteagle_choice);
		self giveWeapon("skorpion_mp");
		self giveWeapon("beretta_mp");
		wait 0.05;
		self switchToWeapon("beretta_mp");
	}
	else
	{
		weapon = self.pers["primaryWeapon"] + "_mp"; // get the primary of whichever class is selected to determine mobility

		switch(weaponClass(weapon))
		{
			case "mg":
				self giveWeapon("m60e4_reflex_mp", 6);	// Gold M60
				break;
			case "rifle":
				self giveWeapon("remington700_mp", 5);	// Blue tiger R700
				break;
			default:
				self giveWeapon("uzi_mp", 6);	// Gold Mini-Uzi
				break;
		}
	}
}

watchMeleeButtonPressed()
{
	self endon("disconnect");
	self endon("end_respawn");

	for(;;)
	{
		if(!self.inMenu && self meleeButtonPressed())
		{
			catch_next = false;

			for(i=0; i<0.5; i+=0.05)
			{
				if(catch_next && self meleeButtonPressed() && self isOnGround())
				{
					self savePos();
					wait .1;
					break;
				}
				else if(!(self meleeButtonPressed()) && !(self attackButtonPressed()))
					catch_next = true;

				wait 0.05;
			}
		}

		wait 0.05;
	}
}

watchSecondaryOffhandButtonPressed()
{
	self endon("disconnect");
	self endon("end_respawn");

	for(;;)
	{
		if(self.sessionstate == "playing" && !self.inMenu && self secondaryOffhandButtonPressed())
		{
			self loadPos();
			wait .1;
		}
		wait 0.05;
	}
}

watchFragButtonPressed()
{
	self endon("disconnect");
	self endon("end_respawn");

	for(;;)
	{
		if(self FragButtonPressed())
		{
			if(self.sessionstate == "playing")
				self thread forgestart();
			else if(self.sessionstate == "spectator")
				self ufoend();

			wait 0.5;
		}

		wait 0.05;
	}
}

savePos()
{
	self.cj["settings"]["rpg_switched"] = false;
	self.cj["save"]["org"] = self.origin;
	self.cj["save"]["ang"] = self getPlayerAngles();
}

loadPos()
{
	self freezecontrols(true);
	wait 0.05;

	self setPlayerAngles(self.cj["save"]["ang"]);
	self setOrigin(self.cj["save"]["org"]);

	self notify("position_loaded");

	//pull out rpg on load if RPG switch is enabled
	if(self.cj["settings"]["rpg_switch_enabled"] && self.cj["settings"]["rpg_switched"])
	{
		self switchToWeapon("rpg_mp");
		self.cj["settings"]["rpg_switched"] = false;
	}

	wait 0.05;
	self freezecontrols(false);
}

initBot()
{
	bot = addtestclient();

	if(!isDefined(bot))
		return undefined;

	bot.pers["isBot"] = true;

	while(!isDefined(bot.pers["team"]))
		wait 0.05;

	bot [[level.axis]]();

	wait 0.5;

	bot.pers["class"] = level.defaultClass;
	bot [[level.spawnClient]]();

	wait .1;

	// plugin handles bot controls
	#if defined(SYSTEM_XENON)
		bot freezeControls(false);
	#else
		bot freezeControls(true);
	#endif

	return bot;
}

watchDPAD_UP()
{
	self endon("end_respawn");
	self endon("disconnect");
	level endon("game_ended");

	self SetActionSlot( 1, "nightvision" );

	for(;;)
	{
		waittill_any("night_vision_on", "night_vision_off");
		self thread spawnSelectedBot();
	}
}

setSelectedBot(num)
{
	self.cj["botnumber"] = num;
	self iPrintLn("Bot " + (num + 1) + " active. Press [{+actionslot 1}] to update position.");
	self refreshMenu();
}

spawnSelectedBot()
{
	if(!isdefined(self.cj["bots"][self.cj["botnumber"]]))
	{
		self.cj["bots"][self.cj["botnumber"]] = initBot();
		if (!isdefined(self.cj["bots"][self.cj["botnumber"]]))
		{
			self iPrintLn("^1Couldn't spawn a bot");
			return;
		}
	}

	origin = self.origin;
	playerAngles = self getPlayerAngles();

	wait 0.5;
	for (i = 3; i > 0; i--)
	{
		self iPrintLn("Bot spawns in ^2" + i);
		wait 1;
	}
	self.cj["bots"][self.cj["botnumber"]] setOrigin(origin);
	// Face the bot the same direction the player was facing
	self.cj["bots"][self.cj["botnumber"]] setPlayerAngles((0, playerAngles[1], 0));
	self.cj["bots"][self.cj["botnumber"]] savePos();	// Save the bot's position for auto mantle
}

toggleOldschool()
{
	setting = "oldschool";
	printName = "Old School Mode";

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == false)
	{
		self.cj["settings"][setting] = true;
		self.cj["settings"]["jump_slowdownEnable"] = false;
		setDvar( "jump_height", 64 );
		setDvar( "jump_slowdownEnable", 0 );
		iPrintln(printName + " [^2ON^7]");
	}
	else
	{
		self.cj["settings"][setting] = false;
		self.cj["settings"]["jump_slowdownEnable"] = true;
		setDvar( "jump_height", 39 );
		setDvar( "jump_slowdownEnable", 1 );
		iPrintln(printName + " [^1OFF^7]");
	}
	for ( i = 0; i < level.players.size; i++ )
	{
		player = level.players[i];
		if(isAlive(player))
		{
			player setupLoadout();
		}
	}
}

toggleJumpSlowdown()
{
	setting = "jump_slowdownEnable";
	printName = setting;

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == false)
	{
		self.cj["settings"][setting] = true;
		setDvar(setting, 1);
		iPrintln(printName + " [^2ON^7]");
	}
	else
	{
		self.cj["settings"][setting] = false;
		setDvar(setting, 0);
		iPrintln(printName + " [^1OFF^7]");
	}
}

toggleShowGun()
{
	setting = "cg_drawgun";
	printName = setting;

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == true)
	{
		self.cj["settings"][setting] = false;
		self setClientDvar(setting, 0);
		self iPrintln(printName + " [^1OFF^7]");
	}
	else
	{
		self.cj["settings"][setting] = true;
		self setClientDvar(setting, 1);
		self iPrintln(printName + " [^2ON^7]");
	}
}

toggleThirdPerson()
{
	setting = "cg_thirdPerson";
	printName = "3rd Person";

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == false)
	{
		self.cj["settings"][setting] = true;
		self setClientDvar(setting, 1);
		self iPrintln(printName + " [^2ON^7]");
	}
	else
	{
		self.cj["settings"][setting] = false;
		self setClientDvar(setting, 0);
		self iPrintln(printName + " [^1OFF^7]");
	}
}

togglePlayerNames()
{
	setting = "cg_overheadnamessize";
	printName = "Player names";

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == true)
	{
		self.cj["settings"][setting] = false;
		self setClientDvar(setting, 0);
		self iPrintln(printName + " [^1OFF^7]");
	}
	else
	{
		self.cj["settings"][setting] = true;
		self setClientDvar(setting, 0.65);
		self iPrintln(printName + " [^2ON^7]");
	}
}

toggleGunBob()
{
	setting = "bg_bobMax";
	printName = "Gun bob";

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == true)
	{
		self.cj["settings"][setting] = false;
		self setClientDvar(setting, 0);
		self iPrintln(printName + " [^1OFF^7]");
	}
	else
	{
		self.cj["settings"][setting] = true;
		self setClientDvar(setting, 8);
		self iPrintln(printName + " [^2ON^7]");
	}
}

addClone()
{
	body = self clonePlayer(100000);
	self.cj["clones"][self.cj["clones"].size] = body;
}

switchDesertEagle()
{
	if(self.cj["settings"]["deserteagle_choice"] == "deserteaglegold_mp")
		self.cj["settings"]["deserteagle_choice"] = "deserteagle_mp";
	else
		self.cj["settings"]["deserteagle_choice"] = "deserteaglegold_mp";

	self setupLoadout();
}

toggleFastReload()
{
	setting = "specialty_fastreload_enable";
	printName = "Sleight of Hand";

	if (self.cj["settings"][setting] == true)
	{
		self.cj["settings"][setting] = false;
		self iPrintln(printName + " [^1OFF^7]");
	}
	else
	{
		self.cj["settings"][setting] = true;
		self iPrintln(printName + " [^2ON^7]");
	}

	self setupLoadout();
}

changeMap(mapname)
{
	Map( mapname );
}

toggleSpectatorButtons()
{
	setting = "cg_drawSpectatorMessages";
	printName = "Spectator Buttons";

	if (!isdefined(self.cj["settings"][setting]) || self.cj["settings"][setting] == true)
	{
		self.cj["settings"][setting] = false;
		self setClientDvar(setting, 0);
		self iPrintln(printName + " [^1OFF^7]");
	}
	else
	{
		self.cj["settings"][setting] = true;
		self setClientDvar(setting, 1);
		self iPrintln(printName + " [^2ON^7]");
	}
}

deleteClones()
{
	clones = self.cj["clones"];

	for(i = 0;i < clones.size;i++)
		clones[i] delete();
}

spawnFloatingBot()
{
	bot = initBot();
	origin = self.origin;
	playerAngles = self getPlayerAngles();

	for (i = 3; i > 0; i--)
	{
		self iPrintLn("Floating bot spawns in ^2" + i);
		wait 1;
	}

	bot setOrigin(origin);
	// Face the bot the same direction the player was facing
	bot setPlayerAngles((0, playerAngles[1], 0));

	self.floating_bot = spawn("script_origin", self.origin);
	bot linkto(self.floating_bot);
}

#if defined(SYSTEM_XENON)
// NOTE: Currently all custom GSC functions require self

removeBarriersOverHeight(height)
{
	self restorebrushcollisions();
	self removebrushcollisionsoverheight(height);
	if(height == 0)
		iprintln("Barriers removed");
	else
		iprintln("Barriers above " + height + " height removed");
}

restoreBarriers()
{
	self restorebrushcollisions();
	iprintln("Barriers restored");
}

toggleAutoMantle()
{
	if (!isdefined(self.cj["settings"]["automantle"]) || self.cj["settings"]["automantle"] == false)
	{
		self.cj["settings"]["automantle"] = true;
		self iprintln("Auto Mantle [^2ON^7]");
		self thread startAutoMantle();
	}
	else
	{
		self.cj["settings"]["automantle"] = false;
		self iprintln("Auto Mantle [^1OFF^7]");
		self stopAutoMantle();
	}
}

modifyTriggerDistance(value)
{
	if (!isdefined(self.triggerDistance))
		self.triggerDistance = 200;

	self.triggerDistance += value;
	self iprintln("Trigger distance: " + self.triggerDistance);
}

startAutoMantle()
{
	self endon("disconnect");
	self endon("death");
	self endon("stop_automantle");

	if (!isdefined(self.triggerDistance))
		self.triggerDistance = 200;
	
	bot = self.cj["bots"][self.cj["botnumber"]];
	if (!isdefined(bot))
	{
		self iprintln("Could not find bot" + self.cj["botnumber"]);
		self.cj["settings"]["automantle"] = false;
		return;
	}
	else
	{
		self iprintln("Watching player: " + bot.name);
		self iprintln("Trigger distance: " + self.triggerDistance);
	}

	bot savePos();
	botEye = bot getEye();

	for (;;)
	{
		if (distance(botEye, self getorigin()) < self.triggerDistance)
		{
			bot botjump();
			self waittill("position_loaded");
			// wait for bot to finish mantling before loading position
			if (bot ismantling())
				wait 0.5;

			bot loadPos();
		}
		wait 0.05;
	}
}

stopAutoMantle()
{
	self notify("stop_automantle");
	self iprintln("Stopped automantle");
}

#endif
