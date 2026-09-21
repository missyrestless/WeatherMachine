///////////////////////////////////////////////////
//         Second Life Weather Machine            //
//                                                //
//     Control the weather in Second Life         //
////////////////////////////////////////////////////

////////////////////////////////////////////////////
// Copyright (c) 2026 Truth & Beauty Lab          //
// License: GPLv3                                 //
// All rights reserved.                           //
//                                                //
// Author: Missy Restless missyrestless@gmail.com //
////////////////////////////////////////////////////

////////////////////////////////////////////////////
//            Modification History                //
//            --------------------                //
// 2026-Sep-21 Created                            //
//                                                //
////////////////////////////////////////////////////

string  VERSION = "1.0.1";

// -------------------------- OWNER CONFIGURATION --------------------------
float   RAIN_RADIUS       = 10.0;
float   RAIN_HEIGHT       = 12.0; // Documented placement height; move the root prim this high
float   RAIN_SPEED        = 1.0;  // Multiplier, clamped by buildRain()
float   RAIN_DENSITY      = 1.0;  // Multiplier, 0.25 through 2.0 recommended
string  RAIN_TEXTURE      = "RAIN";
vector  WIND_DIRECTION    = <1.0, 0.0, 0.0>;
float   WIND_STRENGTH     = 0.0;

float   LIGHTNING_MIN_DELAY = 5.0;
float   LIGHTNING_MAX_DELAY = 30.0;
float   AUTO_PHASE_MIN      = 90.0;
float   AUTO_PHASE_MAX      = 240.0;
integer PUBLIC_CONTROL      = FALSE;
integer START_ON_REZ        = TRUE; // Rain begins immediately after rez/reset

// Controller/Emitter private linked-message protocol
integer LM_FX_EVENT = 1001; // payload: type|night
integer LM_FX_STOP  = 1002;
integer LM_MENU     = 1003; // child prim touch request

integer Storm;
integer Rain = TRUE;
integer Lightning = TRUE;
integer Thunder = TRUE;
integer Ambience = TRUE;
integer Auto;
integer Night;
integer Intensity = 2; // 0 light, 1 normal, 2 heavy, 3 extreme, 4 scary
integer WindMode;       // 0 none, 1 light, 2 strong
float   Volume = 0.75;

float   NextLightning;
float   NextAuto;
float   ThunderDue;
float   MenuExpires;
integer PendingThunder = -1;
integer LastThunder = -1;
integer MenuListen;
integer MenuChannel;
key     MenuUser;
string  MenuPage = "MAIN";
string  LoopName;

list ThunderNames;
list AmbienceNames;
list INTENSITY_NAMES = ["LIGHT RAIN", "RAINSTORM", "THUNDERSTORM", "EXTREME STORM", "SCARY STORM"];
list WIND_NAMES = ["NO WIND", "LIGHT WIND", "STRONG WIND"];

float clamp(float value, float low, float high) {
    if (value < low) return low;
    if (value > high) return high;
    return value;
}

string onOff(integer value) {
    if (value) return "ON";
    return "OFF";
}

float now() {
    return llGetTime();
}

integer inventoryExists(string item, integer inventoryType) {
    if (item == "") return FALSE;
    return (llGetInventoryType(item) == inventoryType);
}

scanInventory() {
    ThunderNames = [];
    AmbienceNames = [];
    integer count = llGetInventoryNumber(INVENTORY_SOUND);
    integer i;
    for (i = 0; i < count; ++i) {
        string item = llGetInventoryName(INVENTORY_SOUND, i);
        if (llSubStringIndex(item, "THUNDER_") == 0) {
            ThunderNames += [item];
        } else if (item == "RAIN_LOOP" || item == "HEAVY_RAIN_LOOP" ||
                 item == "WIND_LOOP" || item == "STORM_AMBIENCE") {
            AmbienceNames += [item];
        }
    }
}

float effectiveWind() {
    if (WindMode == 0) return 0.0;
    if (WindMode == 1) return 1.5;
    if (WIND_STRENGTH > 0.0) return WIND_STRENGTH;
    return 4.0;
}

applyRain() {
    if (!Storm || !Rain) {
        llParticleSystem([]);
        return;
    }

    // Conservative presets prevent a single unit from flooding the viewer.
    list burstRates = [0.16, 0.11, 0.075, 0.045, 0.085];
    list burstCounts = [5, 8, 12, 16, 11];
    list speeds = [7.0, 8.5, 10.0, 12.0, 10.0];
    list lifetimes = [1.7, 1.8, 2.0, 2.2, 2.0];
    list alphas = [0.42, 0.52, 0.66, 0.78, 0.56];
    list spreadFactors = [0.65, 0.82, 1.0, 1.15, 0.95];
    list sizes = [<0.025, 0.65, 0.0>, <0.03, 0.8, 0.0>, <0.035, 1.0, 0.0>,
                  <0.045, 1.25, 0.0>, <0.035, 1.05, 0.0>];

    float density = clamp(RAIN_DENSITY, 0.25, 2.0);
    float rate = llList2Float(burstRates, Intensity) / density;
    integer particles = (integer)((float)llList2Integer(burstCounts, Intensity) * density);
    if (particles < 1) particles = 1;
    if (particles > 24) particles = 24;
    float speed = llList2Float(speeds, Intensity) * clamp(RAIN_SPEED, 0.25, 2.0);
    float life = llList2Float(lifetimes, Intensity);
    vector drift = llVecNorm(WIND_DIRECTION) * effectiveWind();
    // DROP particles begin without directional scatter; acceleration supplies
    // the clean downward fall and makes RAIN_SPEED meaningful for every preset.
    vector acceleration = <drift.x, drift.y, -9.8 * clamp(RAIN_SPEED, 0.25, 2.0)>;
    string texture = "";
    if (inventoryExists(RAIN_TEXTURE, INVENTORY_TEXTURE)) texture = RAIN_TEXTURE;

    integer flags = PSYS_PART_INTERP_COLOR_MASK | PSYS_PART_INTERP_SCALE_MASK |
                    PSYS_PART_FOLLOW_VELOCITY_MASK;
    llParticleSystem([
        PSYS_PART_FLAGS, flags,
        PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_DROP,
        PSYS_SRC_TEXTURE, texture,
        PSYS_SRC_BURST_RATE, rate,
        PSYS_SRC_BURST_PART_COUNT, particles,
        PSYS_SRC_BURST_RADIUS, clamp(RAIN_RADIUS * llList2Float(spreadFactors, Intensity), 0.0, 32.0),
        PSYS_SRC_BURST_SPEED_MIN, speed,
        PSYS_SRC_BURST_SPEED_MAX, speed * 1.18,
        PSYS_SRC_ACCEL, acceleration,
        PSYS_PART_START_COLOR, <0.72, 0.80, 0.90>,
        PSYS_PART_END_COLOR, <0.48, 0.58, 0.70>,
        PSYS_PART_START_ALPHA, llList2Float(alphas, Intensity),
        PSYS_PART_END_ALPHA, 0.08,
        PSYS_PART_START_SCALE, llList2Vector(sizes, Intensity),
        PSYS_PART_END_SCALE, llList2Vector(sizes, Intensity) * 0.55,
        PSYS_PART_MAX_AGE, life,
        PSYS_SRC_MAX_AGE, 0.0
    ]);
}

string desiredLoop() {
    if (!Storm || !Ambience) return "";
    if (Intensity >= 2 && inventoryExists("HEAVY_RAIN_LOOP", INVENTORY_SOUND))
        return "HEAVY_RAIN_LOOP";
    if (inventoryExists("STORM_AMBIENCE", INVENTORY_SOUND)) return "STORM_AMBIENCE";
    if (inventoryExists("RAIN_LOOP", INVENTORY_SOUND)) return "RAIN_LOOP";
    if (WindMode && inventoryExists("WIND_LOOP", INVENTORY_SOUND)) return "WIND_LOOP";
    return "";
}

applyAmbience() {
    string wanted = desiredLoop();
    if (wanted == LoopName) {
        if (wanted != "") llAdjustSoundVolume(Volume * 0.65);
        return;
    }
    llStopSound();
    LoopName = wanted;
    if (wanted != "") llLoopSound(wanted, Volume * 0.65);
}

float lightningDelay() {
    float minimum = LIGHTNING_MIN_DELAY;
    float maximum = LIGHTNING_MAX_DELAY;
    if (maximum < minimum) maximum = minimum;
    float factor = 1.0;
    if (Intensity == 0) factor = 2.3;
    else if (Intensity == 1) factor = 1.35;
    else if (Intensity == 3) factor = 0.65;
    else if (Intensity == 4) factor = 1.65 + llFrand(1.4);
    return (minimum + llFrand(maximum - minimum)) * factor;
}

scheduleLightning() {
    NextLightning = now() + lightningDelay();
}

scheduleAuto() {
    float maximum = AUTO_PHASE_MAX;
    if (maximum < AUTO_PHASE_MIN) maximum = AUTO_PHASE_MIN;
    NextAuto = now() + AUTO_PHASE_MIN + llFrand(maximum - AUTO_PHASE_MIN);
}

setIntensity(integer level) {
    Intensity = level;
    if (Intensity < 0) Intensity = 0;
    if (Intensity > 4) Intensity = 4;
    if (Intensity == 0) {
        WindMode = 0;
    } else if (Intensity == 1) {
        WindMode = 1;
    } else if (Intensity >= 2) {
        WindMode = 2;
    }
    applyRain();
    applyAmbience();
    if (Storm && Lightning) scheduleLightning();
}

playThunder(integer distanceClass, integer major) {
    if (!Storm || !Thunder) return;
    integer count = llGetListLength(ThunderNames);
    if (!count) return;
    integer pick = (integer)llFrand((float)count);
    if (count > 1 && pick == LastThunder) pick = (pick + 1) % count;
    LastThunder = pick;
    float variation = 0.76 + llFrand(0.24);
    if (distanceClass == 2) variation *= 0.62;
    else if (distanceClass == 1) variation *= 0.82;
    if (major) variation = 1.0;
    llTriggerSound(llList2String(ThunderNames, pick), clamp(Volume * variation, 0.0, 1.0));
}

lightningEvent(integer forceMajor) {
    if (!Storm || !Lightning) return;
    integer distanceClass;
    float roll = llFrand(1.0);
    if (roll < 0.28) distanceClass = 2;       // distant
    else if (roll < 0.68) distanceClass = 1;  // medium
    else distanceClass = 0;                   // nearby

    integer major = forceMajor;
    if (!major && llFrand(1.0) < 0.045) major = TRUE;
    integer style = 1 + (integer)llFrand(3.0); // single/double/triple
    if (distanceClass == 2) style = 1;
    if (major) style = 4;
    llMessageLinked(LINK_SET, LM_FX_EVENT,
        (string)style + "|" + (string)distanceClass + "|" + (string)major + "|" + (string)Night, NULL_KEY);

    if (Thunder) {
        float delay;
        if (distanceClass == 0) delay = 0.2 + llFrand(1.3);
        else if (distanceClass == 1) delay = 2.0 + llFrand(2.0);
        else delay = 4.0 + llFrand(4.0);
        if (major) delay = 0.2 + llFrand(0.55);
        PendingThunder = distanceClass + (major * 10);
        ThunderDue = now() + delay;
    }
    scheduleLightning();
}

stopAll() {
    Storm = FALSE;
    PendingThunder = -1;
    NextLightning = 0.0;
    llParticleSystem([]);
    llStopSound();
    LoopName = "";
    llMessageLinked(LINK_SET, LM_FX_STOP, "STOP", NULL_KEY);
}

startStorm() {
    Storm = TRUE;
    applyRain();
    applyAmbience();
    // Make successful setup obvious without creating constant flashing. Later
    // events use the full configured randomized interval.
    NextLightning = now() + 3.0 + llFrand(5.0);
    if (Auto) scheduleAuto();
}

updateTimer() {
    // One modest scheduler handles menus, thunder, lightning and auto phases.
    if (Storm || MenuListen) llSetTimerEvent(0.25);
    else llSetTimerEvent(0.0);
}

closeMenu() {
    if (MenuListen) {
        llListenRemove(MenuListen);
        MenuListen = 0;
    }
    MenuUser = NULL_KEY;
    updateTimer();
}

showDialog(string page) {
    MenuPage = page;
    MenuExpires = now() + 60.0;
    string heading = "Version: " + VERSION + "\n";
    list buttons;
    if (page == "MAIN") {
        // heading += "Storm: " + onOff(Storm) + " | " + llList2String(INTENSITY_NAMES, Intensity);
        heading += statusText(FALSE);
        buttons = ["STORM ON", "STORM OFF", "INTENSITY", "RAIN", "LIGHTNING", "THUNDER",
                   "AMBIENCE", "WIND", "AUTO STORM", "STRIKE", "VOLUME", "MORE"];
    } else if (page == "INTENSITY") {
        buttons = ["LIGHT", "NORMAL", "HEAVY", "EXTREME", "SCARY", "BACK"];
    } else if (page == "VOLUME") {
        buttons = ["25%", "50%", "75%", "100%", "BACK"];
    } else if (page == "WIND") {
        buttons = ["NO WIND", "LIGHT WIND", "STRONG WIND", "BACK"];
    } else if (page == "MORE") {
        buttons = ["STATUS", "DIAGNOSTICS", "DAY/NIGHT", "RESET", "BACK"];
    }
    llDialog(MenuUser, heading, buttons, MenuChannel);
    updateTimer();
}

openMenu(key user) {
    closeMenu();
    MenuUser = user;
    MenuChannel = -100000 - (integer)llFrand(1900000000.0);
    MenuListen = llListen(MenuChannel, "", user, "");
    showDialog("MAIN");
}

string statusText(integer detailed) {
    string text = "Storm: " + onOff(Storm) +
        "\nIntensity: " + llList2String(INTENSITY_NAMES, Intensity) +
        "\nRain: " + onOff(Rain) +
        "\nLightning: " + onOff(Lightning) +
        "\nThunder: " + onOff(Thunder) +
        "\nAmbience: " + onOff(Ambience) +
        "\nAuto Storm: " + onOff(Auto) +
        "\nWind: " + llList2String(WIND_NAMES, WindMode) +
        "\nEnvironment: ";
    if (Night) text += "NIGHT"; else text += "DAY";
    if (detailed) {
        text += "\nThunder sounds: " + (string)llGetListLength(ThunderNames) +
            "\nAmbience sounds: " + (string)llGetListLength(AmbienceNames) +
            "\nRain texture: " + onOff(inventoryExists(RAIN_TEXTURE, INVENTORY_TEXTURE)) +
            "\nFree core memory: " + (string)llGetFreeMemory() + " bytes" +
            "\nEmitter height setting: " + (string)RAIN_HEIGHT + " m";
    }
    return text;
}

handleButton(string message) {
    if (message == "BACK") {
        showDialog("MAIN");
        return;
    }
    if (message == "MORE" || message == "INTENSITY" || message == "VOLUME" || message == "WIND") {
        showDialog(message);
        return;
    }
    if (message == "STORM ON") {
        startStorm();
    } else if (message == "STORM OFF") {
        stopAll();
    } else if (message == "RAIN") {
        Rain = !Rain;
        applyRain();
    } else if (message == "LIGHTNING") {
        Lightning = !Lightning;
        if (!Lightning) {
            llMessageLinked(LINK_SET, LM_FX_STOP, "STOP", NULL_KEY);
        } else {
            scheduleLightning();
        }
    } else if (message == "THUNDER") {
        Thunder = !Thunder;
        if (!Thunder) {
            PendingThunder = -1;
        }
    } else if (message == "AMBIENCE") {
        Ambience = !Ambience;
        applyAmbience();
    } else if (message == "AUTO STORM") {
        Auto = !Auto;
        if (Auto) {
            scheduleAuto();
        }
    } else if (message == "STRIKE") {
        lightningEvent(TRUE);
    } else if (message == "DAY/NIGHT") {
        Night = !Night;
    } else if (message == "STATUS") {
        llOwnerSay(statusText(FALSE));
    } else if (message == "DIAGNOSTICS") {
        scanInventory();
        llOwnerSay(statusText(TRUE));
    } else if (message == "RESET") {
        closeMenu();
        llResetScript();
        return;
    } else if (message == "LIGHT") {
        setIntensity(0);
    } else if (message == "NORMAL") {
        setIntensity(1);
    } else if (message == "HEAVY") {
        setIntensity(2);
    } else if (message == "EXTREME") {
        setIntensity(3);
    } else if (message == "SCARY") {
        setIntensity(4);
    } else if (message == "NO WIND") {
        WindMode = 0;
        applyRain();
    } else if (message == "LIGHT WIND") {
        WindMode = 1;
        applyRain();
    } else if (message == "STRONG WIND") {
        WindMode = 2;
        applyRain();
    } else if (message == "25%") {
        Volume = 0.25;
        applyAmbience();
    } else if (message == "50%") {
        Volume = 0.50;
        applyAmbience();
    } else if (message == "75%") {
        Volume = 0.75;
        applyAmbience();
    } else if (message == "100%") {
        Volume = 1.0;
        applyAmbience();
    }
    updateTimer();
    showDialog(MenuPage);
}

initialize() {
    llResetTime();
    scanInventory();
    Storm = FALSE;
    PendingThunder = -1;
    LoopName = "";
    llParticleSystem([]);
    llStopSound();
    llMessageLinked(LINK_SET, LM_FX_STOP, "STOP", NULL_KEY);
    if (START_ON_REZ) startStorm();
    updateTimer();
}

default {
    state_entry() {
        initialize();
    }

    on_rez(integer startParameter) {
        llResetScript();
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_INVENTORY) {
            scanInventory();
            applyRain();
            applyAmbience();
        }
        if (change & CHANGED_LINK) llMessageLinked(LINK_SET, LM_FX_STOP, "STOP", NULL_KEY);
    }

    touch_start(integer totalNumber) {
        key toucher = llDetectedKey(0);
        if (toucher == llGetOwner() || PUBLIC_CONTROL) openMenu(toucher);
    }

    listen(integer channel, string name, key id, string message) {
        if (channel != MenuChannel || id != MenuUser) return;
        if (id != llGetOwner() && !PUBLIC_CONTROL) return;
        handleButton(message);
    }

    link_message(integer senderNumber, integer number, string message, key id) {
        if (number == LM_MENU && (id == llGetOwner() || PUBLIC_CONTROL))
            openMenu(id);
    }

    timer() {
        float clock = now();
        if (MenuListen && clock >= MenuExpires) closeMenu();
        if (!Storm) { updateTimer(); return; }

        if (PendingThunder >= 0 && clock >= ThunderDue) {
            integer packed = PendingThunder;
            PendingThunder = -1;
            playThunder(packed % 10, packed >= 10);
        }
        if (Lightning && clock >= NextLightning) lightningEvent(FALSE);
        if (Auto && clock >= NextAuto) {
            // Adjacent phases make automatic changes feel progressive.
            integer direction = -1;
            if (llFrand(1.0) >= 0.5) direction = 1;
            integer next = Intensity + direction;
            if (next < 0) next = 1;
            if (next > 3) next = 2;
            setIntensity(next);
            scheduleAuto();
        }
    }
}
