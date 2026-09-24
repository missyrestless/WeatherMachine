////////////////////////////////////////////////////
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
// 2026-Sep-22 Use private channel, not link msg  //
// 2026-Sep-23 Add support for Snow               //
////////////////////////////////////////////////////
//
// Place the Controller script in a child prim

string  VERSION = "1.1.2";

key  Owner;
list FaceColors;
list FaceAlphas;
list FaceGlows;
list FaceFullbright;
list FaceTextures;
list FaceRepeats;
list FaceOffsets;
list FaceRotations;

integer LightEnabled;
vector  LightColor;
float   LightIntensity;
float   LightRadius;
float   LightFalloff;

integer Active;
integer FlashesLeft;
integer Lit;
integer Major;
integer Distance;
integer Night;

// Object communication channel and listener ID
integer objChannel;
integer objListenID;

captureNormal() {
    FaceColors = []; FaceAlphas = []; FaceGlows = []; FaceFullbright = [];
    FaceTextures = []; FaceRepeats = []; FaceOffsets = []; FaceRotations = [];
    integer sides = llGetNumberOfSides();
    integer face;
    for (face = 0; face < sides; ++face) {
        list data = llGetPrimitiveParams([
            PRIM_COLOR, face, PRIM_GLOW, face, PRIM_FULLBRIGHT, face, PRIM_TEXTURE, face]);
        FaceColors += [llList2Vector(data, 0)];
        FaceAlphas += [llList2Float(data, 1)];
        FaceGlows += [llList2Float(data, 2)];
        FaceFullbright += [llList2Integer(data, 3)];
        FaceTextures += [llList2String(data, 4)];
        FaceRepeats += [llList2Vector(data, 5)];
        FaceOffsets += [llList2Vector(data, 6)];
        FaceRotations += [llList2Float(data, 7)];
    }
    list light = llGetPrimitiveParams([PRIM_POINT_LIGHT]);
    LightEnabled = llList2Integer(light, 0);
    LightColor = llList2Vector(light, 1);
    LightIntensity = llList2Float(light, 2);
    LightRadius = llList2Float(light, 3);
    LightFalloff = llList2Float(light, 4);
}

restoreFaces() {
    list rules = [];
    integer sides = llGetListLength(FaceColors);
    integer face;
    for (face = 0; face < sides; ++face) {
        rules += [
            PRIM_COLOR, face, llList2Vector(FaceColors, face), llList2Float(FaceAlphas, face),
            PRIM_GLOW, face, llList2Float(FaceGlows, face),
            PRIM_FULLBRIGHT, face, llList2Integer(FaceFullbright, face),
            PRIM_TEXTURE, face, llList2String(FaceTextures, face),
                llList2Vector(FaceRepeats, face), llList2Vector(FaceOffsets, face),
                llList2Float(FaceRotations, face)
        ];
    }
    rules += [PRIM_POINT_LIGHT, LightEnabled, LightColor, LightIntensity, LightRadius, LightFalloff];
    llSetLinkPrimitiveParamsFast(LINK_THIS, rules);
}

restoreNormal() {
    llSetTimerEvent(0.0);
    llParticleSystem([]);
    restoreFaces();
    Active = FALSE;
    Lit = FALSE;
    FlashesLeft = 0;
}

flashOn() {
    string  bolt_texture = "LIGHTNING_BOLT";
    float   intensity    = 0.72;
    float   radius       = 14.0;
    float   glow         = 0.15;

    if (Distance == 2) {
        intensity = 0.35;
        radius    = 8.0;
        glow      = 0.07;
    } else if (Distance == 0) {
        intensity = 1.0;
        radius    = 20.0;
        glow      = 0.25;
    }
    if (Night) {
        intensity *= 1.15;
        radius    += 3.0;
    }
    if (intensity > 1.0) intensity = 1.0;
    if (Major) {
        intensity = 1.0;
        radius    = 20.0;
        glow      = 0.35;
    }

    list rules = [
        PRIM_COLOR, ALL_SIDES, <1.0, 1.0, 1.0>, 1.0,
        PRIM_GLOW, ALL_SIDES, glow,
        PRIM_FULLBRIGHT, ALL_SIDES, TRUE,
        PRIM_POINT_LIGHT, TRUE, <0.86, 0.92, 1.0>, intensity, radius, 0.55
    ];
    if (Major && llGetInventoryType(bolt_texture) == INVENTORY_TEXTURE)
        rules += [PRIM_TEXTURE, ALL_SIDES, bolt_texture, <1.0, 1.0, 0.0>, ZERO_VECTOR, 0.0];
    llSetLinkPrimitiveParamsFast(LINK_THIS, rules);
    if (Major) {
        llParticleSystem([
            PSYS_PART_FLAGS, PSYS_PART_INTERP_COLOR_MASK | PSYS_PART_INTERP_SCALE_MASK,
            PSYS_SRC_PATTERN, PSYS_SRC_PATTERN_EXPLODE,
            PSYS_SRC_BURST_PART_COUNT, 10,
            PSYS_SRC_BURST_RATE, 0.1,
            PSYS_SRC_BURST_SPEED_MIN, 0.5,
            PSYS_SRC_BURST_SPEED_MAX, 2.0,
            PSYS_PART_START_COLOR, <1.0, 1.0, 1.0>,
            PSYS_PART_END_COLOR, <0.4, 0.6, 1.0>,
            PSYS_PART_START_ALPHA, 0.9,
            PSYS_PART_END_ALPHA, 0.0,
            PSYS_PART_START_SCALE, <0.08, 0.35, 0.0>,
            PSYS_PART_END_SCALE, <0.02, 0.05, 0.0>,
            PSYS_PART_MAX_AGE, 0.45,
            PSYS_SRC_MAX_AGE, 0.12
        ]);
    }
    Lit = TRUE;
    llSetTimerEvent(0.055 + llFrand(0.07));
}

flashOff() {
    llParticleSystem([]);
    restoreFaces();
    Lit = FALSE;
    --FlashesLeft;
    if (FlashesLeft <= 0) {
        Active = FALSE;
        llSetTimerEvent(0.0);
    } else {
        llSetTimerEvent(0.06 + llFrand(0.14));
    }
}

startEvent(integer style, integer distanceClass, integer major, integer night) {
    restoreNormal();
    Distance = distanceClass;
    Major = major;
    Night = night;
    FlashesLeft = style;
    if (Major) FlashesLeft = 4;
    Active = TRUE;
    flashOn();
}

default {
    state_entry() {
        Owner = llGetOwner();
        captureNormal();
        restoreNormal();

        // Compute a large negative channel number based on the object owner
        // All emitters owned by the same owner will use the same channel
        objChannel = 0x80000000 | (integer) ( "0x" + (string) Owner );
        objChannel -= 1;
        llListenRemove(objListenID);
        objListenID = llListen(objChannel, "", NULL_KEY, "");
    }

    changed(integer change) {
        if (change & CHANGED_OWNER) llResetScript();
        if (change & CHANGED_LINK) llResetScript();
        if ((change & CHANGED_INVENTORY) && !Active) captureNormal();
    }

    listen(integer channel, string name, key id, string message) {
        if (channel == objChannel) {
            if (message == "STOP") {
                restoreNormal();
            } else {
                list fields = llParseString2List(message, ["|"], []);
                if (llGetListLength(fields) == 4) {
                    startEvent(llList2Integer(fields, 0), llList2Integer(fields, 1),
                               llList2Integer(fields, 2), llList2Integer(fields, 3));
                }
            }
        }
    }

    touch_start(integer totalNumber) {
        if (llDetectedKey(0) == Owner) {
            llRegionSay(objChannel, "MENU");
        }
    }

    timer() {
        if (!Active) { restoreNormal(); return; }
        if (Lit) flashOff(); else flashOn();
    }

    on_rez(integer startParameter) {
        llResetScript();
    }
}
