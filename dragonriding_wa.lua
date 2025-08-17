{
  "c": [
    {
      "actions": {
        "finish": {
          "custom": "if aura_env.reshow then\n  UIWidgetPowerBarContainerFrame:Show()\n  aura_env.reshow = false\nend\naura_env.cancelCallback()",
          "do_custom": true
        },
        "init": {
          "custom": "---- Constants ----\n\nlocal ascentSpellId = 372610\nlocal thrillBuffId = 377234\nlocal maxPassiveGlideSpeed = 65\nlocal slowSkyridingRatio = 705/830\nlocal maxSamples = 2\nlocal ascentDuration = 3.5\nlocal updatePeriod = 1/20\nlocal fastFlyingZones = {\n    [2444] = true, -- Dragon Isles\n    [2454] = true, -- Zaralek Cavern\n    [2548] = true, -- Emerald Dream\n    \n    [2516] = true, -- Nokhud Offensive\n    \n    [2522] = true, -- Vault of the Incarnates\n    [2569] = true, -- Aberrus, the Shadowed Crucible\n}\n\n---- Parameters ----\n\nlocal showSpeed = aura_env.config.speedshow\nlocal hideBlizz = aura_env.config.hideblizz\n\nlocal speedTextFormat\nlocal speedTextFactor = 1\nif aura_env.config.speedunits == 1 then\n    speedTextFormat = aura_env.config.speedshowunits and \"%.1fyd/s\" or \"%.1f\"\nelse\n    speedTextFormat = aura_env.config.speedshowunits and \"%.0f%%\" or \"%.0f\"\n    speedTextFactor = 100 / BASE_MOVEMENT_SPEED\nend\n\n---- Variables ----\n\nlocal active = false\nlocal updateHandle = nil\nlocal ascentStart = 0\nlocal samples = 0\nlocal lastSpeed, lastT = 0, 0\nlocal smoothAccel = 0\nlocal isSlowSkyriding = true\n\n---- Trigger 1 ----\n\n-- Events:\n--   UNIT_SPELLCAST_SUCCEEDED:player\n--   DMUI_DRAGONRIDING_UPDATE\n\nlocal function setActive(allstates, state)\n    active = state\n    C_Timer.After(0, function()\n            WeakAuras.ScanEvents(\"DMUI_DRAGONRIDING_SHOW\", state)\n    end)\n    \n    if active then\n        if hideBlizz and UIWidgetPowerBarContainerFrame:IsVisible() then\n            aura_env.reshow = true\n            UIWidgetPowerBarContainerFrame:Hide()\n        end\n        \n        if not updateHandle then\n            updateHandle = C_Timer.NewTicker(updatePeriod, function()\n                    if active then\n                        WeakAuras.ScanEvents(\"DMUI_DRAGONRIDING_UPDATE\", true)\n                    end\n            end)\n        end\n        \n        if not allstates[\"\"] then\n            allstates[\"\"] = {\n                show = true,\n                changed = true,\n                progressType = \"static\",\n                value = 0,\n                accel = 0,\n                total = 100,\n                boosting = false,\n                thrill = false,\n                speedtext = \"\",\n                angle = \"\",\n            }\n            return true\n        end\n    else\n        if updateHandle then\n            updateHandle:Cancel()\n            updateHandle = nil\n        end\n        \n        if allstates[\"\"] then\n            allstates[\"\"].show = false\n            allstates[\"\"].changed = true\n            return true\n        end\n    end\nend\n\naura_env.cancelCallback = function()\n    if updateHandle then\n        updateHandle:Cancel()\n        updateHandle = nil\n    end\nend\n\naura_env.trigger1 = function(allstates, event, _, _, spellId)\n    if event ~= \"DMUI_DRAGONRIDING_UDPATE\" then\n        if event == \"OPTIONS\" then\n            return setActive(allstates, false)\n        end\n        \n        if event == \"STATUS\" then\n            isSlowSkyriding = not fastFlyingZones[select(8, GetInstanceInfo())]\n            return setActive(allstates, true)\n        end\n        \n        -- Detect ascent boost\n        \n        if event == \"UNIT_SPELLCAST_SUCCEEDED\" then\n            if spellId == ascentSpellId then\n                ascentStart = GetTime()\n            end\n            return false\n        end\n    end\n    \n    -- Time\n    \n    local time = GetTime()\n    local dt = time - lastT\n    lastT = time\n    \n    if not allstates or not allstates[\"\"] then return false end\n    \n    -- Get flying speed\n    \n    local isGliding, _, forwardSpeed = C_PlayerInfo.GetGlidingInfo()\n    local speed = forwardSpeed\n    \n    local thrill = C_UnitAuras.GetPlayerAuraBySpellID(thrillBuffId)\n    local boosting = thrill and time < ascentStart + ascentDuration\n    \n    local adjustedSpeed = speed\n    if isSlowSkyriding then\n        adjustedSpeed = adjustedSpeed / slowSkyridingRatio\n    end\n    \n    -- Compute smooth acceleration\n    \n    samples = math.min(maxSamples, samples + 1)\n    local lastWeight = (samples - 1) / samples\n    local newWeight = 1 / samples\n    \n    local newAccel = (adjustedSpeed - lastSpeed) / dt\n    lastSpeed = adjustedSpeed\n    \n    smoothAccel = smoothAccel * lastWeight + newAccel * newWeight\n    \n    if adjustedSpeed >= maxPassiveGlideSpeed or not isGliding then\n        smoothAccel = 0 -- Don't track when boosting or on ground\n        samples = 0\n    end\n    \n    WeakAuras.ScanEvents(\"DMUI_DRAGONRIDING_ACCEL\", smoothAccel)\n    \n    -- Update display variables\n    local s = allstates[\"\"]\n    s.changed = true\n    s.value = adjustedSpeed\n    s.boosting = boosting\n    s.thrill = not not thrill\n    s.gliding = isGliding\n    s.accel = smoothAccel\n    if showSpeed then\n        s.speedtext = speed < 1 and \"\" or string.format(speedTextFormat, speed * speedTextFactor)\n    end\n    \n    return true\nend",
          "do_custom": true
        },
        "start": {
          "custom": "",
          "do_custom": false
        }
      },
      "adjustedMax": "100",
      "adjustedMin": "20",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:Dragonriding UI Pitch",
      "anchorFrameParent": true,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "TOP",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "alpha": 0,
          "colorA": 1,
          "colorB": 0.015686275437474,
          "colorFunc": "function(_, r1, g1, b1, a1, r2, g2, b2, a2)\n    local progress = 1 - math.min(1, math.max(aura_env.smooth_accel + 0.5, 0))\n    if not aura_env.boosting then\n        return WeakAuras.GetHSVTransition(progress, r1, g1, b1, a1, r2, g2, b2, a2)\n    else\n        return r1, g1, b1, a1\n    end\nend",
          "colorG": 0,
          "colorR": 0.74901962280273,
          "colorType": "custom",
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "rotate": 0,
          "scalex": 1,
          "scaley": 1,
          "type": "custom",
          "use_color": false,
          "x": 0,
          "y": 0
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Blizzard UI",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Hides the default Blizzard Dragonriding UI",
          "key": "hideblizz",
          "name": "Hide Blizz UI",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "text": "Speed",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Display speed on bar.",
          "key": "speedshow",
          "name": "Display Speed Value",
          "type": "toggle",
          "useDesc": true,
          "width": 1.05
        },
        {
          "default": true,
          "desc": "Whether to display units after speed value.",
          "key": "speedshowunits",
          "name": "Show Units",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "default": 2,
          "desc": "Format to display speed value in.",
          "key": "speedunits",
          "name": "Speed Units",
          "type": "select",
          "useDesc": true,
          "values": [
            "yd/s",
            "move%"
          ],
          "width": 1
        },
        {
          "text": "Minimal Ground UI",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "automaticWidth": "Auto",
      "backgroundColor": [
        0,
        0,
        0,
        0.60000002384186
      ],
      "barColor": [
        0.20784315466881,
        0.65490198135376,
        0.88235300779343,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.16862745583057,
                0.69411766529083,
                0.22352942824364,
                1
              ]
            }
          ],
          "check": {
            "trigger": 1,
            "value": 1,
            "variable": "boosting"
          }
        },
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.69411766529083,
                0.094117656350136,
                0.070588238537312,
                1
              ]
            }
          ],
          "check": {
            "checks": [
              {
                "trigger": 1,
                "value": 0,
                "variable": "thrill"
              },
              {
                "trigger": 2,
                "value": 0,
                "variable": "show"
              }
            ],
            "trigger": 1,
            "value": 0,
            "variable": "thrill"
          },
          "linked": false
        },
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.54509806632996,
                0.27843138575554,
                0.80392163991928,
                1
              ]
            }
          ],
          "check": {
            "checks": [
              {
                "trigger": 1,
                "value": 0,
                "variable": "thrill"
              },
              {
                "trigger": 2,
                "value": 1,
                "variable": "show"
              }
            ],
            "trigger": -2,
            "variable": "AND"
          }
        },
        {
          "changes": [
            {
              "property": "alpha"
            }
          ],
          "check": {
            "checks": [
              {
                "op": "<=",
                "trigger": 1,
                "value": "0",
                "variable": "value"
              },
              {
                "trigger": 4,
                "value": 1,
                "variable": "show"
              }
            ],
            "op": ">=",
            "trigger": -2,
            "variable": "AND"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 1
            }
          ],
          "check": {
            "trigger": 3,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideblizz": true,
        "hideground": false,
        "speedshow": true,
        "speedshowunits": true,
        "speedunits": 2
      },
      "customTextUpdate": "event",
      "desaturate": false,
      "displayText": "Pitch: %p",
      "displayText_format_p_format": "timed",
      "displayText_format_p_time_dynamic_threshold": 60,
      "displayText_format_p_time_format": 0,
      "displayText_format_p_time_legacy_floor": false,
      "displayText_format_p_time_mod_rate": true,
      "displayText_format_p_time_precision": 1,
      "enableGradient": false,
      "fixedWidth": 200,
      "font": "Friz Quadrata TT",
      "fontSize": 12,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 19.2,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - Speed",
      "information": {
        "forceEvents": false
      },
      "internalVersion": 84,
      "inverse": false,
      "justify": "LEFT",
      "load": {
        "class": {
          "multi": []
        },
        "class_and_spec": [],
        "difficulty": {
          "multi": [],
          "single": "timewalking"
        },
        "ingroup": [],
        "instance_type": [],
        "itemtypeequipped": [],
        "size": {
          "multi": {
            "none": true
          },
          "single": "none"
        },
        "spec": {
          "multi": []
        },
        "spellknown": 372610,
        "talent": {
          "multi": []
        },
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spellknown": false,
        "use_zoneIds": false,
        "zoneIds": ""
      },
      "orientation": "HORIZONTAL",
      "outline": "OUTLINE",
      "parent": "DragonRiding",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "shadowColor": [
        0,
        0,
        0,
        1
      ],
      "shadowXOffset": 1,
      "shadowYOffset": -1,
      "smoothProgress": true,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "automatic_length": true,
          "progressSources": [
            [
              -2,
              ""
            ]
          ],
          "tick_blend_mode": "ADD",
          "tick_color": [
            0,
            0,
            0,
            1
          ],
          "tick_desaturate": false,
          "tick_length": 18,
          "tick_mirror": false,
          "tick_placement": "50",
          "tick_placement_mode": "AtValue",
          "tick_placements": [
            "60"
          ],
          "tick_rotation": 0,
          "tick_texture": "450918",
          "tick_thickness": 1,
          "tick_visible": true,
          "tick_xOffset": 0,
          "tick_yOffset": 0,
          "type": "subtick",
          "use_texture": false
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "INNER_LEFT",
          "rotateText": "NONE",
          "text_anchorXOffset": 0,
          "text_anchorYOffset": -0.5,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            0
          ],
          "text_shadowXOffset": 2,
          "text_shadowYOffset": -1,
          "text_text": "%1.speedtext",
          "text_text_format_.speedtext_format": "none",
          "text_text_format_1.speedtext_format": "none",
          "text_text_format_n_format": "none",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "Number",
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 60,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": false,
          "text_text_format_p_time_mod_rate": true,
          "text_text_format_p_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "check": "event",
            "custom": "function(...)\n  return aura_env.trigger1(...)\nend",
            "customDuration": "function()\n    return aura_env.smooth_delta + 0.5, 1, true\nend",
            "customVariables": "{\n    value = \"number\",\n    delta = \"number\",\n    boosting = \"bool\",\n    thrill = \"bool\",\n    gliding = \"bool\",\n}",
            "custom_hide": "timed",
            "custom_type": "stateupdate",
            "debuffType": "HELPFUL",
            "event": "Health",
            "events": "UNIT_SPELLCAST_SUCCEEDED:player, DMUI_DRAGONRIDING_UPDATE",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "404184"
            ],
            "auraspellids": [
              "404184"
            ],
            "debuffType": "HELPFUL",
            "ownOnly": true,
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "auranames": [
              "378415",
              "369968",
              "392559"
            ],
            "debuffType": "HELPFUL",
            "type": "aura2",
            "unit": "player",
            "useName": true
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and not IsFlying() then\n        return true\n    end\nend\n\n\n",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[1]) or (aura_env.config.hideground and t[1] and t[4])\nend",
        "disjunctive": "any"
      },
      "uid": "ANDMedxweeF",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": true,
      "useAdjustededMin": true,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 254.9,
      "wordWrap": "WordWrap",
      "xOffset": 0.1,
      "yOffset": 17.296051025391,
      "zoom": 0
    },
    {
      "actions": {
        "finish": [],
        "init": [],
        "start": []
      },
      "align": "CENTER",
      "alpha": 1,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animate": false,
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "arcLength": 360,
      "authorOptions": [],
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "border": false,
      "borderBackdrop": "Blizzard Tooltip",
      "borderColor": [
        0,
        0,
        0,
        1
      ],
      "borderEdge": "Square Full White",
      "borderInset": 1,
      "borderOffset": 4,
      "borderSize": 2,
      "centerType": "LR",
      "columnSpace": 1,
      "conditions": [],
      "config": [],
      "constantFactor": "RADIUS",
      "controlledChildren": [
        "DR - SW1",
        "DR - SW2",
        "DR - SW3"
      ],
      "frameStrata": 1,
      "fullCircle": true,
      "gridType": "RD",
      "gridWidth": 5,
      "groupIcon": 4640489,
      "grow": "HORIZONTAL",
      "id": "DR - Second Wind",
      "information": {
        "forceEvents": true
      },
      "internalVersion": 84,
      "limit": 5,
      "load": {
        "class": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        }
      },
      "parent": "DragonRiding",
      "radius": 200,
      "regionType": "dynamicgroup",
      "rotation": 0,
      "rowSpace": 1,
      "scale": 1,
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "sort": "none",
      "sortHybridTable": {
        "DR - SW1": false,
        "DR - SW2": false,
        "DR - SW3": false
      },
      "source": "import",
      "space": 3,
      "stagger": 0,
      "stepAngle": 15,
      "tocversion": 110105,
      "triggers": [
        {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player"
          },
          "untrigger": []
        }
      ],
      "uid": "1gAkNdVIglB",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useLimit": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "xOffset": 0,
      "yOffset": 32.3
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": "",
          "do_custom": false
        },
        "start": []
      },
      "adjustedMax": "100",
      "adjustedMin": "20",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:Dragonriding UI Pitch",
      "anchorFrameParent": true,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "TOP",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "fade",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "fade",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "automaticWidth": "Auto",
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "backdropInFront": false,
      "backgroundColor": [
        0,
        0,
        0,
        0.60061725974083
      ],
      "barColor": [
        0.88235300779343,
        0.8666667342186,
        0.78431379795074,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "borderBackdrop": "None",
      "borderInFront": false,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.47450983524323,
                0.47450983524323,
                0.47450983524323,
                1
              ]
            }
          ],
          "check": {
            "op": "==",
            "trigger": 1,
            "value": "0",
            "variable": "charges"
          }
        },
        {
          "changes": [
            {
              "property": "alpha"
            }
          ],
          "check": {
            "trigger": 4,
            "value": 1,
            "variable": "show"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 0.2
            }
          ],
          "check": {
            "trigger": 3,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideground": false
      },
      "customText": "",
      "customTextUpdate": "event",
      "desaturate": false,
      "displayText": "Pitch: %p",
      "displayText_format_p_format": "timed",
      "displayText_format_p_time_dynamic_threshold": 60,
      "displayText_format_p_time_format": 0,
      "displayText_format_p_time_legacy_floor": false,
      "displayText_format_p_time_mod_rate": true,
      "displayText_format_p_time_precision": 1,
      "enableGradient": false,
      "fixedWidth": 200,
      "font": "Friz Quadrata TT",
      "fontFlags": "OUTLINE",
      "fontSize": 12,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 4.2,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - SW1",
      "information": {
        "forceEvents": false
      },
      "internalVersion": 84,
      "inverse": true,
      "justify": "LEFT",
      "load": {
        "class": {
          "multi": {
            "DEATHKNIGHT": true,
            "DRUID": true,
            "MAGE": true,
            "MONK": true,
            "PALADIN": true,
            "ROGUE": true,
            "SHAMAN": true,
            "WARLOCK": true,
            "WARRIOR": true
          },
          "single": "PALADIN"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            true,
            null,
            null,
            null,
            true
          ],
          "single": 70
        },
        "difficulty": {
          "multi": []
        },
        "faction": {
          "multi": []
        },
        "ingroup": {
          "multi": []
        },
        "pvptalent": {
          "multi": []
        },
        "race": {
          "multi": []
        },
        "role": {
          "multi": {
            "DAMAGER": true
          },
          "single": "DAMAGER"
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [
            null,
            true,
            true
          ],
          "single": 3
        },
        "spellknown": 425782,
        "talent": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            null,
            true
          ]
        },
        "talent2": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spellknown": false,
        "zoneIds": ""
      },
      "orientation": "HORIZONTAL",
      "outline": "OUTLINE",
      "parent": "DR - Second Wind",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "shadowColor": [
        0,
        0,
        0,
        1
      ],
      "shadowXOffset": 1,
      "shadowYOffset": -1,
      "smoothProgress": false,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkDesature": false,
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "stickyDuration": false,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "auranames": [
              "205473"
            ],
            "castType": "cast",
            "charges": "1",
            "charges_operator": ">=",
            "custom_hide": "timed",
            "debuffType": "HELPFUL",
            "duration": "1",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "matchesShowOn": "showAlways",
            "names": [],
            "ownOnly": true,
            "power": [
              "1"
            ],
            "power_operator": [
              ">="
            ],
            "powertype": 9,
            "realSpellName": "Second Wind",
            "spellIds": [],
            "spellName": 425782,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "track": "charges",
            "trackcharge": "1",
            "type": "spell",
            "unevent": "auto",
            "unit": "player",
            "useName": true,
            "use_castType": false,
            "use_charges": false,
            "use_genericShowOn": true,
            "use_power": true,
            "use_powertype": true,
            "use_spellName": true,
            "use_track": true,
            "use_trackcharge": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "Riding Along"
            ],
            "debuffType": "HARMFUL",
            "event": "Conditions",
            "ownOnly": true,
            "type": "unit",
            "unit": "player",
            "useName": true,
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_alwaystrue": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "auranames": [
              "378415",
              "369968",
              "392559"
            ],
            "auraspellids": [
              "369968"
            ],
            "debuffType": "HELPFUL",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and not IsFlying() then\n        return true\n    end\nend",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t) return t[1] and (not t[2]) end",
        "disjunctive": "any"
      },
      "uid": "4r8dX(e7i3n",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 27,
      "wordWrap": "WordWrap",
      "xOffset": 0,
      "yOffset": 0,
      "zoom": 0
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": "",
          "do_custom": false
        },
        "start": []
      },
      "adjustedMax": "100",
      "adjustedMin": "20",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:Dragonriding UI Pitch",
      "anchorFrameParent": true,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "TOP",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "fade",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "fade",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "automaticWidth": "Auto",
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "backdropInFront": false,
      "backgroundColor": [
        0,
        0,
        0,
        0.60061725974083
      ],
      "barColor": [
        0.88235300779343,
        0.8666667342186,
        0.78431379795074,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "borderBackdrop": "None",
      "borderInFront": false,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.47450983524323,
                0.47450983524323,
                0.47450983524323,
                1
              ]
            }
          ],
          "check": {
            "op": "==",
            "trigger": 1,
            "value": "1",
            "variable": "charges"
          }
        },
        {
          "changes": [
            {
              "property": "alpha"
            }
          ],
          "check": {
            "trigger": 4,
            "value": 1,
            "variable": "show"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 0.2
            }
          ],
          "check": {
            "trigger": 3,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideground": false
      },
      "customText": "",
      "customTextUpdate": "event",
      "desaturate": false,
      "displayText": "Pitch: %p",
      "displayText_format_p_format": "timed",
      "displayText_format_p_time_dynamic_threshold": 60,
      "displayText_format_p_time_format": 0,
      "displayText_format_p_time_legacy_floor": false,
      "displayText_format_p_time_mod_rate": true,
      "displayText_format_p_time_precision": 1,
      "enableGradient": false,
      "fixedWidth": 200,
      "font": "Friz Quadrata TT",
      "fontFlags": "OUTLINE",
      "fontSize": 12,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 4.2,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - SW2",
      "information": {
        "forceEvents": false
      },
      "internalVersion": 84,
      "inverse": true,
      "justify": "LEFT",
      "load": {
        "class": {
          "multi": {
            "DEATHKNIGHT": true,
            "DRUID": true,
            "MAGE": true,
            "MONK": true,
            "PALADIN": true,
            "ROGUE": true,
            "SHAMAN": true,
            "WARLOCK": true,
            "WARRIOR": true
          },
          "single": "PALADIN"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            true,
            null,
            null,
            null,
            true
          ],
          "single": 70
        },
        "difficulty": {
          "multi": []
        },
        "faction": {
          "multi": []
        },
        "ingroup": {
          "multi": []
        },
        "pvptalent": {
          "multi": []
        },
        "race": {
          "multi": []
        },
        "role": {
          "multi": {
            "DAMAGER": true
          },
          "single": "DAMAGER"
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [
            null,
            true,
            true
          ],
          "single": 3
        },
        "spellknown": 425782,
        "talent": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            null,
            true
          ]
        },
        "talent2": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spellknown": false,
        "zoneIds": ""
      },
      "orientation": "HORIZONTAL",
      "outline": "OUTLINE",
      "parent": "DR - Second Wind",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "shadowColor": [
        0,
        0,
        0,
        1
      ],
      "shadowXOffset": 1,
      "shadowYOffset": -1,
      "smoothProgress": false,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkDesature": false,
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "stickyDuration": false,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "auranames": [
              "205473"
            ],
            "castType": "cast",
            "charges": "2",
            "charges_operator": ">=",
            "custom_hide": "timed",
            "debuffType": "HELPFUL",
            "duration": "1",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "matchesShowOn": "showAlways",
            "names": [],
            "ownOnly": true,
            "power": [
              "2"
            ],
            "power_operator": [
              ">="
            ],
            "powertype": 9,
            "realSpellName": "Second Wind",
            "spellIds": [],
            "spellName": 425782,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "track": "auto",
            "trackcharge": "2",
            "type": "spell",
            "unevent": "auto",
            "unit": "player",
            "useName": true,
            "use_castType": false,
            "use_charges": false,
            "use_genericShowOn": true,
            "use_power": true,
            "use_powertype": true,
            "use_spellName": true,
            "use_track": true,
            "use_trackcharge": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "Riding Along"
            ],
            "debuffType": "HARMFUL",
            "event": "Conditions",
            "ownOnly": true,
            "type": "unit",
            "unit": "player",
            "useName": true,
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_alwaystrue": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "auranames": [
              "378415",
              "369968",
              "392559"
            ],
            "auraspellids": [
              "369968"
            ],
            "debuffType": "HELPFUL",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and not IsFlying() then\n        return true\n    end\nend",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t) return t[1] and (not t[2]) end",
        "disjunctive": "any"
      },
      "uid": "5Re3YiyQEag",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 27,
      "wordWrap": "WordWrap",
      "xOffset": 0,
      "yOffset": 0,
      "zoom": 0
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": "",
          "do_custom": false
        },
        "start": []
      },
      "adjustedMax": "100",
      "adjustedMin": "20",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:Dragonriding UI Pitch",
      "anchorFrameParent": true,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "TOP",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "fade",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "preset": "bounceDecay",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "automaticWidth": "Auto",
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "backdropInFront": false,
      "backgroundColor": [
        0,
        0,
        0,
        0.60061725974083
      ],
      "barColor": [
        0.88235300779343,
        0.8666667342186,
        0.78431379795074,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "borderBackdrop": "None",
      "borderInFront": false,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.47450983524323,
                0.47450983524323,
                0.47450983524323,
                1
              ]
            }
          ],
          "check": {
            "op": "==",
            "trigger": 1,
            "value": "2",
            "variable": "charges"
          }
        },
        {
          "changes": [
            {
              "property": "alpha"
            }
          ],
          "check": {
            "trigger": 4,
            "value": 1,
            "variable": "show"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 0.2
            }
          ],
          "check": {
            "trigger": 3,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideground": false
      },
      "customText": "",
      "customTextUpdate": "event",
      "desaturate": false,
      "displayText": "Pitch: %p",
      "displayText_format_p_format": "timed",
      "displayText_format_p_time_dynamic_threshold": 60,
      "displayText_format_p_time_format": 0,
      "displayText_format_p_time_legacy_floor": false,
      "displayText_format_p_time_mod_rate": true,
      "displayText_format_p_time_precision": 1,
      "enableGradient": false,
      "fixedWidth": 200,
      "font": "Friz Quadrata TT",
      "fontFlags": "OUTLINE",
      "fontSize": 12,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 4.2,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - SW3",
      "information": {
        "forceEvents": false
      },
      "internalVersion": 84,
      "inverse": true,
      "justify": "LEFT",
      "load": {
        "class": {
          "multi": {
            "DEATHKNIGHT": true,
            "DRUID": true,
            "MAGE": true,
            "MONK": true,
            "PALADIN": true,
            "ROGUE": true,
            "SHAMAN": true,
            "WARLOCK": true,
            "WARRIOR": true
          },
          "single": "PALADIN"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            true,
            null,
            null,
            null,
            true
          ],
          "single": 70
        },
        "difficulty": {
          "multi": []
        },
        "faction": {
          "multi": []
        },
        "ingroup": {
          "multi": []
        },
        "pvptalent": {
          "multi": []
        },
        "race": {
          "multi": []
        },
        "role": {
          "multi": {
            "DAMAGER": true
          },
          "single": "DAMAGER"
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [
            null,
            true,
            true
          ],
          "single": 3
        },
        "spellknown": 425782,
        "talent": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            true,
            null,
            true
          ]
        },
        "talent2": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spellknown": false,
        "zoneIds": ""
      },
      "orientation": "HORIZONTAL",
      "outline": "OUTLINE",
      "parent": "DR - Second Wind",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "shadowColor": [
        0,
        0,
        0,
        1
      ],
      "shadowXOffset": 1,
      "shadowYOffset": -1,
      "smoothProgress": false,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkDesature": false,
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "stickyDuration": false,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "auranames": [
              "205473"
            ],
            "castType": "cast",
            "charges": "3",
            "charges_operator": ">=",
            "custom_hide": "timed",
            "debuffType": "HELPFUL",
            "duration": "1",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "matchesShowOn": "showAlways",
            "names": [],
            "ownOnly": true,
            "power": [
              "3"
            ],
            "power_operator": [
              ">="
            ],
            "powertype": 9,
            "realSpellName": "Second Wind",
            "spellIds": [],
            "spellName": 425782,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "track": "auto",
            "trackcharge": "3",
            "type": "spell",
            "unevent": "auto",
            "unit": "player",
            "useName": true,
            "use_castType": false,
            "use_charges": false,
            "use_genericShowOn": true,
            "use_power": true,
            "use_powertype": true,
            "use_spellName": true,
            "use_track": true,
            "use_trackcharge": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "Riding Along"
            ],
            "debuffType": "HARMFUL",
            "event": "Conditions",
            "ownOnly": true,
            "type": "unit",
            "unit": "player",
            "useName": true,
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_alwaystrue": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "auranames": [
              "378415",
              "369968",
              "392559"
            ],
            "auraspellids": [
              "369968"
            ],
            "debuffType": "HELPFUL",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and not IsFlying() then\n        return true\n    end\nend",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t) return t[1] and (not t[2]) end",
        "disjunctive": "any"
      },
      "uid": "itOsAj2xw1g",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 27,
      "wordWrap": "WordWrap",
      "xOffset": 0,
      "yOffset": 0,
      "zoom": 0
    },
    {
      "actions": {
        "finish": [],
        "init": [],
        "start": []
      },
      "align": "CENTER",
      "alpha": 1,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "BOTTOMLEFT",
      "animate": false,
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "arcLength": 360,
      "authorOptions": [],
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "border": false,
      "borderBackdrop": "Blizzard Tooltip",
      "borderColor": [
        0,
        0,
        0,
        1
      ],
      "borderEdge": "Square Full White",
      "borderInset": 1,
      "borderOffset": 4,
      "borderSize": 2,
      "centerType": "LR",
      "columnSpace": 1,
      "conditions": [],
      "config": [],
      "constantFactor": "RADIUS",
      "controlledChildren": [
        "DR - Vigor Bar"
      ],
      "frameStrata": 1,
      "fullCircle": true,
      "gridType": "RD",
      "gridWidth": 5,
      "groupIcon": 134377,
      "grow": "HORIZONTAL",
      "id": "DR - Vigor",
      "information": {
        "forceEvents": true
      },
      "internalVersion": 84,
      "limit": 5,
      "load": {
        "class": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        }
      },
      "parent": "DragonRiding",
      "radius": 200,
      "regionType": "dynamicgroup",
      "rotation": 0,
      "rowSpace": 1,
      "scale": 1,
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "sort": "none",
      "sortHybridTable": {
        "DR - Vigor Bar": false
      },
      "source": "import",
      "space": 3,
      "stagger": 0,
      "stepAngle": 15,
      "subRegions": [],
      "tocversion": 110105,
      "triggers": [
        {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player"
          },
          "untrigger": []
        }
      ],
      "uid": "RhD0l5n)O)y",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useLimit": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "xOffset": 0.15,
      "yOffset": 0.000091552734375
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": "aura_env.vigorWidgetId = 4460",
          "do_custom": true
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "backgroundColor": [
        0,
        0,
        0,
        0.60061725974083
      ],
      "barColor": [
        0.20784315466881,
        0.65490198135376,
        0.88235300779343,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "barColor",
              "value": [
                0.47450983524323,
                0.47450983524323,
                0.47450983524323,
                1
              ]
            }
          ],
          "check": {
            "op": "<",
            "trigger": 1,
            "value": "100",
            "variable": "value"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 0.1
            }
          ],
          "check": {
            "trigger": 3,
            "value": 1,
            "variable": "show"
          }
        },
        {
          "changes": [
            {
              "property": "alpha",
              "value": 1
            }
          ],
          "check": {
            "trigger": 4,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideground": false
      },
      "desaturate": false,
      "enableGradient": false,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 10,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - Vigor Bar",
      "information": [],
      "internalVersion": 84,
      "inverse": false,
      "load": {
        "class": {
          "multi": []
        },
        "class_and_spec": [],
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        },
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false
      },
      "orientation": "HORIZONTAL",
      "parent": "DR - Vigor",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "smoothProgress": false,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "custom": "function(states, event, data)\n    if (data and data.widgetID ~= aura_env.vigorWidgetId) then return end\n    \n    local widgetInfo = C_UIWidgetManager.GetFillUpFramesWidgetVisualizationInfo(aura_env.vigorWidgetId)\n    \n    for _, state in pairs(states) do\n        state.show = false;\n        state.changed = true;\n    end\n    \n    if (widgetInfo) then  \n        for i=1, widgetInfo.numTotalFrames do\n            states[i] = states[i] or {}\n            local s = states[i]\n            \n            s.show = true\n            s.changed = true\n            s.progressType = 'static'\n            s.total = widgetInfo.fillMax\n            \n            if (widgetInfo.numFullFrames >= i) then\n                s.value =  widgetInfo.fillMax\n            elseif (widgetInfo.numFullFrames + 1 == i) then\n                s.value =  widgetInfo.fillValue\n            else \n                s.value = widgetInfo.fillMin\n            end\n        end\n        \n    end \n    \n    if (aura_env.config.hide and UIWidgetPowerBarContainerFrame and UIWidgetPowerBarContainerFrame.widgetFrames[aura_env.vigorWidgetId]) then\n        if (UIWidgetPowerBarContainerFrame.widgetFrames[aura_env.vigorWidgetId]:IsShown()) then\n            UIWidgetPowerBarContainerFrame.widgetFrames[aura_env.vigorWidgetId]:Hide()\n        end\n    end\n    \n    return true\nend\n\n\n",
            "customVariables": "{\n   value = true\n}",
            "custom_hide": "timed",
            "custom_type": "stateupdate",
            "debuffType": "HELPFUL",
            "event": "Power",
            "events": "UPDATE_UI_WIDGET",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "custom",
            "unit": "player",
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_powertype": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "377234"
            ],
            "auraspellids": [
              "377234"
            ],
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and not IsFlying() then\n        return true\n    end\nend\n\n\n",
            "custom_hide": "timed",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "duration": "5",
            "events": "DMUI_DRAGONRIDING_UPDATE, UPDATE_UI_WIDGET",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "auranames": [
              "378415",
              "369968",
              "392559"
            ],
            "auraspellids": [
              "369968",
              "392559"
            ],
            "debuffType": "HELPFUL",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "ownOnly": true,
            "track": "auto",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true,
            "use_genericShowOn": true,
            "use_spellName": true,
            "use_track": true
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "disjunctive": "any"
      },
      "uid": "VNnaZ0x8DR0",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 40,
      "xOffset": 0,
      "yOffset": 0,
      "zoom": 0
    },
    {
      "actions": {
        "finish": {
          "custom": "if aura_env.reshow then\n    EncounterBar:Show()\n    aura_env.reshow = false\nend",
          "do_custom": false
        },
        "init": {
          "custom": "aura_env.vigor = 0\naura_env.charge = 0",
          "do_custom": true
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:Dragonriding UI",
      "anchorFrameType": "SCREEN",
      "anchorPoint": "TOP",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [],
      "backgroundColor": [
        0,
        0,
        0,
        0.60000002384186
      ],
      "barColor": [
        0.88235300779343,
        0.76470595598221,
        0.258823543787,
        1
      ],
      "barColor2": [
        1,
        1,
        0,
        1
      ],
      "conditions": [],
      "config": [],
      "desaturate": false,
      "enableGradient": false,
      "frameStrata": 1,
      "gradientOrientation": "HORIZONTAL",
      "height": 4.1999983787537,
      "icon": false,
      "iconSource": -1,
      "icon_color": [
        1,
        1,
        1,
        1
      ],
      "icon_side": "RIGHT",
      "id": "DR - Momentum",
      "information": {
        "forceEvents": true
      },
      "internalVersion": 84,
      "inverse": false,
      "load": {
        "class": {
          "multi": []
        },
        "class_and_spec": [],
        "namerealm": "zfe",
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        },
        "use_dragonriding": true,
        "use_namerealm": false,
        "use_never": false,
        "use_petbattle": false
      },
      "orientation": "HORIZONTAL",
      "parent": "DragonRiding",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "aurabar",
      "selfPoint": "BOTTOM",
      "semver": "1.0.52",
      "smoothProgress": true,
      "source": "import",
      "spark": false,
      "sparkBlendMode": "ADD",
      "sparkColor": [
        1,
        1,
        1,
        1
      ],
      "sparkHeight": 30,
      "sparkHidden": "NEVER",
      "sparkOffsetX": 0,
      "sparkOffsetY": 0,
      "sparkRotation": 0,
      "sparkRotationMode": "AUTO",
      "sparkTexture": "Interface\\CastingBar\\UI-CastingBar-Spark",
      "sparkWidth": 10,
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "type": "subforeground"
        },
        {
          "anchor_area": "bar",
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 1,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        }
      ],
      "texture": "Solid",
      "textureSource": "LSM",
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "debuffType": "HELPFUL",
            "duration": "3.0",
            "event": "Spell Cast Succeeded",
            "genericShowOn": "showOnCooldown",
            "names": [],
            "realSpellName": 0,
            "spellId": [
              "372610"
            ],
            "spellIds": [],
            "spellName": 0,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "event",
            "unit": "player",
            "use_genericShowOn": true,
            "use_spellId": true,
            "use_spellName": true,
            "use_track": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "377234"
            ],
            "auraspellids": [
              "377234"
            ],
            "debuffType": "HELPFUL",
            "event": "Conditions",
            "genericShowOn": "showOnCooldown",
            "itemName": 0,
            "realSpellName": 0,
            "spellName": 0,
            "subeventPrefix": "",
            "subeventSuffix": "",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true,
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_alwaystrue": true,
            "use_eventtype": true,
            "use_genericShowOn": true,
            "use_itemName": true,
            "use_spellName": true,
            "use_track": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if IsFlying() then\n        return true\n    end\nend\n\n\n",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "disjunctive": "all"
      },
      "uid": "3etPBSjKJNc",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 255.00019836426,
      "xOffset": 0.55889892578125,
      "yOffset": -11.941009521484,
      "zoom": 0
    },
    {
      "actions": {
        "finish": [],
        "init": [],
        "start": []
      },
      "alpha": 1,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [],
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "border": false,
      "borderBackdrop": "Blizzard Tooltip",
      "borderColor": [
        0,
        0,
        0,
        1
      ],
      "borderEdge": "Square Full White",
      "borderInset": 1,
      "borderOffset": 4,
      "borderSize": 2,
      "conditions": [],
      "config": [],
      "controlledChildren": [
        "DR - Spells [R]",
        "DR - Spells [L]"
      ],
      "frameStrata": 1,
      "groupIcon": "236766",
      "id": "DR - Spells",
      "information": [],
      "internalVersion": 84,
      "load": {
        "class": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        }
      },
      "parent": "DragonRiding",
      "regionType": "group",
      "scale": 1,
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [],
      "tocversion": 110105,
      "triggers": [
        {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player"
          },
          "untrigger": []
        }
      ],
      "uid": "meFwKTe0oEk",
      "url": "https://wago.io/x5C6gaJRB/53",
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "xOffset": 0,
      "yOffset": 1
    },
    {
      "actions": {
        "finish": [],
        "init": [],
        "start": []
      },
      "align": "CENTER",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:DragonRiding - Show",
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animate": false,
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "arcLength": 360,
      "authorOptions": [],
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "border": false,
      "borderBackdrop": "Blizzard Tooltip",
      "borderColor": [
        0,
        0,
        0,
        1
      ],
      "borderEdge": "Square Full White",
      "borderInset": 1,
      "borderOffset": 4,
      "borderSize": 2,
      "centerType": "LR",
      "columnSpace": 1,
      "conditions": [],
      "config": [],
      "constantFactor": "RADIUS",
      "controlledChildren": [
        "DR - Lightning Rush CD",
        "DR - Whirling Surge",
        "DR - Static Charge"
      ],
      "frameStrata": 1,
      "fullCircle": true,
      "gridType": "RD",
      "gridWidth": 5,
      "groupIcon": 236766,
      "grow": "RIGHT",
      "id": "DR - Spells [R]",
      "information": [],
      "internalVersion": 84,
      "limit": 5,
      "load": {
        "class": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        }
      },
      "parent": "DR - Spells",
      "radius": 200,
      "regionType": "dynamicgroup",
      "rotation": 0,
      "rowSpace": 1,
      "scale": 1,
      "selfPoint": "LEFT",
      "semver": "1.0.52",
      "sort": "none",
      "sortHybridTable": {
        "DR - Lightning Rush CD": false,
        "DR - Static Charge": false,
        "DR - Whirling Surge": false
      },
      "source": "import",
      "space": 2,
      "stagger": 0,
      "stepAngle": 15,
      "subRegions": [],
      "tocversion": 110105,
      "triggers": [
        {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player"
          },
          "untrigger": []
        }
      ],
      "uid": "gw3qRvI1ovm",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAnchorPerUnit": false,
      "useLimit": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "xOffset": 129,
      "yOffset": 10
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": ""
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameParent": false,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Spell Tracking",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Track Lightning Rush",
          "key": "rush",
          "name": "Lightning Rush",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "sub.4.text_visible",
              "value": true
            },
            {
              "property": "sub.3.text_visible"
            },
            {
              "property": "desaturate"
            },
            {
              "property": "inverse"
            }
          ],
          "check": {
            "trigger": 2,
            "value": 1,
            "variable": "show"
          }
        }
      ],
      "config": {
        "hideground": false,
        "rush": true
      },
      "cooldown": true,
      "cooldownEdge": false,
      "cooldownSwipe": true,
      "cooldownTextDisabled": true,
      "desaturate": true,
      "displayIcon": 252174,
      "frameStrata": 1,
      "height": 34,
      "icon": true,
      "iconSource": 0,
      "id": "DR - Lightning Rush CD",
      "information": {
        "forceEvents": true,
        "ignoreOptionsEventErrors": true
      },
      "internalVersion": 84,
      "inverse": true,
      "keepAspectRatio": false,
      "load": {
        "class": {
          "multi": [],
          "single": "MONK"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true
          ],
          "single": 270
        },
        "itemtypeequipped": [],
        "role": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [],
          "single": 2
        },
        "talent": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spec": true,
        "use_spellknown": false
      },
      "parent": "DR - Spells [R]",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "icon",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 0,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 0.8,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%1.p",
          "text_text_format_1.p_format": "timed",
          "text_text_format_1.p_time_dynamic_threshold": 0,
          "text_text_format_1.p_time_format": 0,
          "text_text_format_1.p_time_legacy_floor": false,
          "text_text_format_1.p_time_mod_rate": false,
          "text_text_format_1.p_time_precision": 1,
          "text_text_format_2.p_format": "timed",
          "text_text_format_2.p_time_dynamic_threshold": 0,
          "text_text_format_2.p_time_format": 0,
          "text_text_format_2.p_time_legacy_floor": false,
          "text_text_format_2.p_time_mod_rate": true,
          "text_text_format_2.p_time_precision": 1,
          "text_text_format_2p_format": "none",
          "text_text_format_c_format": "none",
          "text_text_format_p_abbreviate": false,
          "text_text_format_p_abbreviate_max": 8,
          "text_text_format_p_big_number_format": "AbbreviateNumbers",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "GCDTime",
          "text_text_format_p_gcd_cast": false,
          "text_text_format_p_gcd_channel": false,
          "text_text_format_p_gcd_gcd": true,
          "text_text_format_p_gcd_hide_zero": false,
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 0,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": true,
          "text_text_format_p_time_mod_rate": true,
          "text_text_format_p_time_precision": 1,
          "text_text_format_t_format": "timed",
          "text_text_format_t_time_dynamic_threshold": 60,
          "text_text_format_t_time_format": 0,
          "text_text_format_t_time_legacy_floor": false,
          "text_text_format_t_time_mod_rate": true,
          "text_text_format_t_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 0.8,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%2.p",
          "text_text_format_2.p_format": "timed",
          "text_text_format_2.p_time_dynamic_threshold": 0,
          "text_text_format_2.p_time_format": 0,
          "text_text_format_2.p_time_legacy_floor": false,
          "text_text_format_2.p_time_mod_rate": false,
          "text_text_format_2.p_time_precision": 1,
          "text_text_format_2p_format": "none",
          "text_text_format_3.p_format": "timed",
          "text_text_format_3.p_time_dynamic_threshold": 0,
          "text_text_format_3.p_time_format": 0,
          "text_text_format_3.p_time_legacy_floor": false,
          "text_text_format_3.p_time_mod_rate": true,
          "text_text_format_3.p_time_precision": 1,
          "text_text_format_c_format": "none",
          "text_text_format_p_abbreviate": false,
          "text_text_format_p_abbreviate_max": 8,
          "text_text_format_p_big_number_format": "AbbreviateNumbers",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "GCDTime",
          "text_text_format_p_gcd_cast": false,
          "text_text_format_p_gcd_channel": false,
          "text_text_format_p_gcd_gcd": true,
          "text_text_format_p_gcd_hide_zero": false,
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 0,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": true,
          "text_text_format_p_time_mod_rate": true,
          "text_text_format_p_time_precision": 1,
          "text_text_format_t_format": "timed",
          "text_text_format_t_time_dynamic_threshold": 60,
          "text_text_format_t_time_format": 0,
          "text_text_format_t_time_legacy_floor": false,
          "text_text_format_t_time_mod_rate": true,
          "text_text_format_t_time_precision": 1,
          "text_visible": false,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        }
      ],
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "debuffType": "HELPFUL",
            "duration": "30",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "names": [],
            "sourceUnit": "player",
            "spellId": [
              418592
            ],
            "spellIds": [],
            "spellName": 418592,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_SUCCESS",
            "track": "auto",
            "type": "spell",
            "unit": "player",
            "use_exact_spellName": true,
            "use_genericShowOn": true,
            "use_ignoreoverride": true,
            "use_sourceUnit": true,
            "use_spellId": true,
            "use_spellName": true,
            "use_track": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "418592"
            ],
            "auraspellids": [
              "418592"
            ],
            "debuffType": "HELPFUL",
            "ownOnly": true,
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": true,
            "useName": false
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "custom": "function()\n    if aura_env.config.rush then\n        return true\n    end\nend\n\n\n",
            "custom_hide": "timed",
            "custom_type": "event",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and IsFlying() then\n        return true\n    end\nend",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[1] and t[3]) or (aura_env.config.hideground and t[1] and t[3] and t[4])\nend",
        "disjunctive": "custom"
      },
      "uid": "1EXRZ6kBNVR",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "useCooldownModRate": false,
      "useTooltip": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 34,
      "xOffset": 2,
      "yOffset": 0,
      "zoom": 0.3
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": ""
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameParent": false,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Spell Tracking",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Track Whirling Surge",
          "key": "surge",
          "name": "Whirling Surge",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [],
      "config": {
        "hideground": false,
        "surge": true
      },
      "cooldown": true,
      "cooldownEdge": false,
      "cooldownSwipe": true,
      "cooldownTextDisabled": true,
      "desaturate": true,
      "displayIcon": "4640477",
      "frameStrata": 1,
      "height": 34,
      "icon": true,
      "iconSource": 0,
      "id": "DR - Whirling Surge",
      "information": {
        "forceEvents": true,
        "ignoreOptionsEventErrors": true
      },
      "internalVersion": 84,
      "inverse": true,
      "keepAspectRatio": false,
      "load": {
        "class": {
          "multi": [],
          "single": "MONK"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true
          ],
          "single": 270
        },
        "itemtypeequipped": [],
        "role": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [],
          "single": 2
        },
        "talent": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spec": true,
        "use_spellknown": false
      },
      "parent": "DR - Spells [R]",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "icon",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 0,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 0.8,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%p",
          "text_text_format_p_abbreviate": false,
          "text_text_format_p_abbreviate_max": 8,
          "text_text_format_p_big_number_format": "AbbreviateNumbers",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "timed",
          "text_text_format_p_gcd_cast": false,
          "text_text_format_p_gcd_channel": false,
          "text_text_format_p_gcd_gcd": true,
          "text_text_format_p_gcd_hide_zero": false,
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 0,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": false,
          "text_text_format_p_time_mod_rate": false,
          "text_text_format_p_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        }
      ],
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "debuffType": "HELPFUL",
            "duration": "30",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "names": [],
            "realSpellName": 361584,
            "sourceUnit": "player",
            "spellId": [
              361584
            ],
            "spellIds": [],
            "spellName": 361584,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_SUCCESS",
            "track": "auto",
            "type": "spell",
            "unit": "player",
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_exact_spellName": true,
            "use_genericShowOn": true,
            "use_ignoreoverride": true,
            "use_showgcd": false,
            "use_sourceUnit": true,
            "use_spellId": true,
            "use_spellName": true,
            "use_track": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "custom": "function()\n    if aura_env.config.surge then\n        return true\n    end\nend\n\n\n",
            "custom_hide": "timed",
            "custom_type": "event",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and IsFlying() then\n        return true\n    end\nend",
            "custom_hide": "timed",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[1] and t[2]) or (aura_env.config.hideground and t[1] and t[2] and t[3])\nend",
        "disjunctive": "custom"
      },
      "uid": "opbORlazVt8",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "useCooldownModRate": false,
      "useTooltip": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 34,
      "xOffset": 2,
      "yOffset": 0,
      "zoom": 0.3
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": "\n\n-- Do not remove this comment, it is part of this aura: DR - Bronze Rewind"
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Spell Tracking",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Track Static Charge",
          "key": "static",
          "name": "Static Charge",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "sub.4.glow",
              "value": true
            }
          ],
          "check": {
            "checks": [
              {
                "op": "==",
                "trigger": 1,
                "value": "10",
                "variable": "stacks"
              },
              {
                "value": 0,
                "variable": "onCooldown"
              }
            ],
            "op": "==",
            "trigger": 1,
            "value": "10",
            "variable": "stacks"
          }
        }
      ],
      "config": {
        "static": true
      },
      "cooldown": true,
      "cooldownEdge": false,
      "cooldownSwipe": true,
      "cooldownTextDisabled": true,
      "desaturate": false,
      "displayIcon": "4554440",
      "frameStrata": 1,
      "height": 34,
      "icon": true,
      "iconSource": -1,
      "id": "DR - Static Charge",
      "information": [],
      "internalVersion": 84,
      "inverse": false,
      "keepAspectRatio": false,
      "load": {
        "class": {
          "multi": []
        },
        "class_and_spec": [],
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        },
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false
      },
      "parent": "DR - Spells [R]",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "icon",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 0,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 0.8,
          "text_anchorYOffset": 0,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "CENTER",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%s",
          "text_text_format_p_format": "timed",
          "text_text_format_p_time_dynamic_threshold": 60,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": false,
          "text_text_format_p_time_mod_rate": true,
          "text_text_format_p_time_precision": 1,
          "text_text_format_s_format": "timed",
          "text_text_format_s_time_dynamic_threshold": 0,
          "text_text_format_s_time_format": 0,
          "text_text_format_s_time_legacy_floor": false,
          "text_text_format_s_time_mod_rate": false,
          "text_text_format_s_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        },
        {
          "glow": false,
          "glowBorder": false,
          "glowColor": [
            1,
            1,
            1,
            1
          ],
          "glowDuration": 1,
          "glowFrequency": 0.25,
          "glowLength": 10,
          "glowLines": 8,
          "glowScale": 1,
          "glowThickness": 1,
          "glowType": "Proc",
          "glowXOffset": 0,
          "glowYOffset": 0,
          "type": "subglow",
          "useGlowColor": false
        }
      ],
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "auranames": [
              "418590"
            ],
            "auraspellids": [
              "418590"
            ],
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "ownOnly": true,
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": true,
            "useName": false
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.static then\n        return true\n    end\nend\n\n\n",
            "custom_hide": "timed",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if IsFlying() then\n        return true\n    end\nend",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": 1,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[1] and t[2]) or (aura_env.config.hideground and t[1] and t[2] and t[3])\nend",
        "disjunctive": "all"
      },
      "uid": "3PPrZ1HNj5Z",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "useCooldownModRate": true,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 34,
      "xOffset": 2.0000190734863,
      "yOffset": 0,
      "zoom": 0.3
    },
    {
      "actions": {
        "finish": [],
        "init": [],
        "start": []
      },
      "align": "CENTER",
      "alpha": 1,
      "anchorFrameFrame": "WeakAuras:DragonRiding - Show",
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animate": false,
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "arcLength": 360,
      "authorOptions": [],
      "backdropColor": [
        1,
        1,
        1,
        0.5
      ],
      "border": false,
      "borderBackdrop": "Blizzard Tooltip",
      "borderColor": [
        0,
        0,
        0,
        1
      ],
      "borderEdge": "Square Full White",
      "borderInset": 1,
      "borderOffset": 4,
      "borderSize": 2,
      "centerType": "LR",
      "columnSpace": 1,
      "conditions": [],
      "config": [],
      "constantFactor": "RADIUS",
      "controlledChildren": [
        "DR - Bronze Rewind",
        "DR - Aerial Halt"
      ],
      "frameStrata": 1,
      "fullCircle": true,
      "gridType": "RD",
      "gridWidth": 5,
      "groupIcon": 236766,
      "grow": "LEFT",
      "id": "DR - Spells [L]",
      "information": [],
      "internalVersion": 84,
      "limit": 5,
      "load": {
        "class": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": []
        },
        "talent": {
          "multi": []
        }
      },
      "parent": "DR - Spells",
      "radius": 200,
      "regionType": "dynamicgroup",
      "rotation": 0,
      "rowSpace": 1,
      "scale": 1,
      "selfPoint": "RIGHT",
      "semver": "1.0.52",
      "sort": "none",
      "sortHybridTable": {
        "DR - Aerial Halt": false,
        "DR - Bronze Rewind": false
      },
      "source": "import",
      "space": 2,
      "stagger": 0,
      "stepAngle": 15,
      "subRegions": [],
      "tocversion": 110105,
      "triggers": [
        {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Health",
            "names": [],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "type": "aura2",
            "unit": "player"
          },
          "untrigger": []
        }
      ],
      "uid": "eKQDe6F0G8T",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAnchorPerUnit": false,
      "useLimit": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "xOffset": -132,
      "yOffset": 10
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": ""
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameParent": false,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Spell Tracking",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Track Bronze Timelock",
          "key": "bronze",
          "name": "Bronze Timelock",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [
        {
          "changes": [
            {
              "property": "sub.3.text_visible",
              "value": true
            },
            {
              "property": "desaturate",
              "value": true
            }
          ],
          "check": {
            "checks": [
              {
                "trigger": 1,
                "value": 1,
                "variable": "onCooldown"
              },
              {
                "value": 0,
                "variable": "show"
              }
            ],
            "trigger": 1,
            "value": 1,
            "variable": "onCooldown"
          }
        },
        {
          "changes": [
            {
              "property": "inverse"
            },
            {
              "property": "sub.4.glow",
              "value": true
            }
          ],
          "check": {
            "checks": [
              {
                "trigger": 2,
                "value": 1,
                "variable": "show"
              }
            ],
            "trigger": 2,
            "value": 1,
            "variable": "show"
          }
        },
        {
          "changes": [
            {
              "property": "sub.3.text_color",
              "value": [
                1,
                0,
                0.0039215688593686,
                1
              ]
            }
          ],
          "check": {
            "op": "<=",
            "trigger": 2,
            "value": "20",
            "variable": "expirationTime"
          }
        }
      ],
      "config": {
        "bronze": true,
        "hideground": false
      },
      "cooldown": true,
      "cooldownEdge": false,
      "cooldownSwipe": true,
      "cooldownTextDisabled": true,
      "desaturate": false,
      "displayIcon": 134156,
      "frameStrata": 1,
      "height": 34,
      "icon": true,
      "iconSource": -1,
      "id": "DR - Bronze Rewind",
      "information": {
        "forceEvents": true,
        "ignoreOptionsEventErrors": true
      },
      "internalVersion": 84,
      "inverse": true,
      "keepAspectRatio": false,
      "load": {
        "class": {
          "multi": [],
          "single": "MONK"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true
          ],
          "single": 270
        },
        "itemtypeequipped": [],
        "role": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [],
          "single": 2
        },
        "talent": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spec": true,
        "use_spellknown": false
      },
      "parent": "DR - Spells [L]",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "icon",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 0,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 1.1,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%p",
          "text_text_format_p_abbreviate": false,
          "text_text_format_p_abbreviate_max": 8,
          "text_text_format_p_big_number_format": "AbbreviateNumbers",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "timed",
          "text_text_format_p_gcd_cast": false,
          "text_text_format_p_gcd_channel": false,
          "text_text_format_p_gcd_gcd": true,
          "text_text_format_p_gcd_hide_zero": false,
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 0,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": false,
          "text_text_format_p_time_mod_rate": false,
          "text_text_format_p_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        },
        {
          "glow": false,
          "glowBorder": false,
          "glowColor": [
            1,
            1,
            1,
            1
          ],
          "glowDuration": 1,
          "glowFrequency": 0.17,
          "glowLength": 10,
          "glowLines": 7,
          "glowScale": 1,
          "glowThickness": 1,
          "glowType": "Pixel",
          "glowXOffset": 0,
          "glowYOffset": 0,
          "type": "subglow",
          "useGlowColor": false
        }
      ],
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "debuffType": "HELPFUL",
            "event": "Cooldown Progress (Spell)",
            "genericShowOn": "showOnCooldown",
            "names": [],
            "realSpellName": 374990,
            "spellId": "372610",
            "spellIds": [],
            "spellName": 374990,
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_START",
            "track": "auto",
            "type": "spell",
            "unit": "player",
            "use_absorbHealMode": true,
            "use_absorbMode": true,
            "use_exact_spellName": true,
            "use_genericShowOn": true,
            "use_ignoreoverride": true,
            "use_showgcd": true,
            "use_spellId": true,
            "use_spellName": true,
            "use_track": true,
            "use_unit": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "auranames": [
              "375585"
            ],
            "auraspellids": [
              "375585"
            ],
            "debuffType": "HELPFUL",
            "ownOnly": true,
            "type": "aura2",
            "unit": "player",
            "useExactSpellId": false,
            "useName": true
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "custom": "function()\n    if aura_env.config.bronze then\n        return true\n    end\nend\n\n\n\n\n",
            "custom_hide": "timed",
            "custom_type": "event",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "4": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and IsFlying() then\n        return true\n    end\nend",
            "custom_hide": "timed",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[3] and (t[1] or t[2])) or (aura_env.config.hideground and t[3] and (t[1] or t[2]) and t[4])\nend\n\n\n",
        "disjunctive": "custom"
      },
      "uid": "CMFtDtZxXr2",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "useCooldownModRate": true,
      "useTooltip": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 34,
      "xOffset": 2,
      "yOffset": 0,
      "zoom": 0.3
    },
    {
      "actions": {
        "finish": [],
        "init": {
          "custom": ""
        },
        "start": []
      },
      "adjustedMax": "",
      "adjustedMin": "",
      "alpha": 1,
      "anchorFrameParent": false,
      "anchorFrameType": "SCREEN",
      "anchorPoint": "CENTER",
      "animation": {
        "finish": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "main": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        },
        "start": {
          "duration_type": "seconds",
          "easeStrength": 3,
          "easeType": "none",
          "type": "none"
        }
      },
      "authorOptions": [
        {
          "text": "Spell Tracking",
          "type": "header",
          "useName": true,
          "width": 1
        },
        {
          "default": true,
          "desc": "Track Aerial Halt",
          "key": "halt",
          "name": "Aerial Halt",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        },
        {
          "default": false,
          "desc": "Hides parts of the UI while on the ground",
          "key": "hideground",
          "name": "Minimal UI on ground",
          "type": "toggle",
          "useDesc": true,
          "width": 1
        }
      ],
      "auto": true,
      "color": [
        1,
        1,
        1,
        1
      ],
      "conditions": [],
      "config": {
        "halt": true,
        "hideground": false
      },
      "cooldown": true,
      "cooldownEdge": false,
      "cooldownSwipe": true,
      "cooldownTextDisabled": true,
      "desaturate": true,
      "displayIcon": 5003205,
      "frameStrata": 1,
      "height": 34,
      "icon": true,
      "iconSource": -1,
      "id": "DR - Aerial Halt",
      "information": {
        "forceEvents": true,
        "ignoreOptionsEventErrors": true
      },
      "internalVersion": 84,
      "inverse": true,
      "keepAspectRatio": false,
      "load": {
        "class": {
          "multi": [],
          "single": "MONK"
        },
        "class_and_spec": {
          "multi": [
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            true
          ],
          "single": 270
        },
        "itemtypeequipped": [],
        "role": {
          "multi": []
        },
        "size": {
          "multi": []
        },
        "spec": {
          "multi": [],
          "single": 2
        },
        "talent": {
          "multi": []
        },
        "use_class": true,
        "use_dragonriding": true,
        "use_never": false,
        "use_petbattle": false,
        "use_spec": true,
        "use_spellknown": false
      },
      "parent": "DR - Spells [L]",
      "progressSource": [
        -1,
        ""
      ],
      "regionType": "icon",
      "selfPoint": "CENTER",
      "semver": "1.0.52",
      "source": "import",
      "subRegions": [
        {
          "type": "subbackground"
        },
        {
          "border_color": [
            0,
            0,
            0,
            1
          ],
          "border_edge": "Square Full White",
          "border_offset": 0,
          "border_size": 1,
          "border_visible": true,
          "type": "subborder"
        },
        {
          "anchorXOffset": 0,
          "anchorYOffset": 0,
          "anchor_point": "CENTER",
          "rotateText": "NONE",
          "text_anchorXOffset": 0.8,
          "text_automaticWidth": "Auto",
          "text_color": [
            1,
            1,
            1,
            1
          ],
          "text_fixedWidth": 64,
          "text_font": "Fira Sans Medium",
          "text_fontSize": 16,
          "text_fontType": "OUTLINE",
          "text_justify": "CENTER",
          "text_selfPoint": "AUTO",
          "text_shadowColor": [
            0,
            0,
            0,
            1
          ],
          "text_shadowXOffset": 0,
          "text_shadowYOffset": 0,
          "text_text": "%p",
          "text_text_format_1.p_format": "timed",
          "text_text_format_1.p_time_dynamic_threshold": 60,
          "text_text_format_1.p_time_format": 0,
          "text_text_format_1.p_time_legacy_floor": false,
          "text_text_format_1.p_time_mod_rate": true,
          "text_text_format_1.p_time_precision": 1,
          "text_text_format_2.p_format": "timed",
          "text_text_format_2.p_time_dynamic_threshold": 0,
          "text_text_format_2.p_time_format": 0,
          "text_text_format_2.p_time_legacy_floor": false,
          "text_text_format_2.p_time_mod_rate": true,
          "text_text_format_2.p_time_precision": 1,
          "text_text_format_2p_format": "none",
          "text_text_format_c_format": "none",
          "text_text_format_p_abbreviate": false,
          "text_text_format_p_abbreviate_max": 8,
          "text_text_format_p_big_number_format": "AbbreviateNumbers",
          "text_text_format_p_decimal_precision": 0,
          "text_text_format_p_format": "timed",
          "text_text_format_p_gcd_cast": false,
          "text_text_format_p_gcd_channel": false,
          "text_text_format_p_gcd_gcd": true,
          "text_text_format_p_gcd_hide_zero": false,
          "text_text_format_p_round_type": "floor",
          "text_text_format_p_time_dynamic_threshold": 0,
          "text_text_format_p_time_format": 0,
          "text_text_format_p_time_legacy_floor": false,
          "text_text_format_p_time_mod_rate": false,
          "text_text_format_p_time_precision": 1,
          "text_text_format_t_format": "timed",
          "text_text_format_t_time_dynamic_threshold": 60,
          "text_text_format_t_time_format": 0,
          "text_text_format_t_time_legacy_floor": false,
          "text_text_format_t_time_mod_rate": true,
          "text_text_format_t_time_precision": 1,
          "text_visible": true,
          "text_wordWrap": "WordWrap",
          "type": "subtext"
        }
      ],
      "tocversion": 110105,
      "triggers": {
        "1": {
          "trigger": {
            "debuffType": "HELPFUL",
            "duration": "10",
            "event": "Combat Log",
            "names": [],
            "sourceUnit": "player",
            "spellId": [
              403092
            ],
            "spellIds": [],
            "subeventPrefix": "SPELL",
            "subeventSuffix": "_CAST_SUCCESS",
            "type": "combatlog",
            "unit": "player",
            "use_sourceUnit": true,
            "use_spellId": true
          },
          "untrigger": []
        },
        "2": {
          "trigger": {
            "custom": "function()\n    if aura_env.config.halt then\n        return true\n    end\nend\n\n\n\n\n",
            "custom_hide": "timed",
            "custom_type": "event",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_ACCEL",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "3": {
          "trigger": {
            "check": "event",
            "custom": "function()\n    if aura_env.config.hideground and IsFlying() then\n        return true\n    end\nend\n\n\n",
            "custom_type": "status",
            "debuffType": "HELPFUL",
            "events": "DMUI_DRAGONRIDING_UPDATE",
            "type": "custom",
            "unit": "player"
          },
          "untrigger": []
        },
        "activeTriggerMode": -10,
        "customTriggerLogic": "function(t)\n    return (not aura_env.config.hideground and t[1] and t[2]) or (aura_env.config.hideground and t[1] and t[2] and t[3])\nend",
        "disjunctive": "custom"
      },
      "uid": "HaHG6ejw5hJ",
      "url": "https://wago.io/x5C6gaJRB/53",
      "useAdjustededMax": false,
      "useAdjustededMin": false,
      "useCooldownModRate": false,
      "useTooltip": false,
      "version": 53,
      "wagoID": "x5C6gaJRB",
      "width": 34,
      "xOffset": 2,
      "yOffset": 0,
      "zoom": 0.3
    }
  ],
  "d": {
    "actions": {
      "finish": [],
      "init": [],
      "start": []
    },
    "alpha": 1,
    "anchorFrameType": "SCREEN",
    "anchorPoint": "CENTER",
    "animation": {
      "finish": {
        "duration_type": "seconds",
        "easeStrength": 3,
        "easeType": "none",
        "type": "none"
      },
      "main": {
        "duration_type": "seconds",
        "easeStrength": 3,
        "easeType": "none",
        "type": "none"
      },
      "start": {
        "duration_type": "seconds",
        "easeStrength": 3,
        "easeType": "none",
        "type": "none"
      }
    },
    "authorOptions": [],
    "backdropColor": [
      1,
      1,
      1,
      0.5
    ],
    "border": false,
    "borderBackdrop": "Blizzard Tooltip",
    "borderColor": [
      0,
      0,
      0,
      1
    ],
    "borderEdge": "Square Full White",
    "borderInset": 1,
    "borderOffset": 4,
    "borderSize": 2,
    "conditions": [],
    "config": [],
    "controlledChildren": [
      "DR - Speed",
      "DR - Second Wind",
      "DR - Vigor",
      "DR - Momentum",
      "DR - Spells"
    ],
    "desc": "\n-----------------------------------------------------------------------------------------------\nSpeed bar color info: \nBlue = Gaining vigor from thrill of the skies\nPurple = Gaining vigor from ground skimming\nGreen = Gaining momentum from skyward ascent\nRed = Not gaining any vigor \n3 White bars = Second wind stacks tracker, turns gray when it's recharging\n\nMinimalistic UI while on the ground can be enabled in custom options\n-----------------------------------------------------------------------------------------------\n\n",
    "frameStrata": 1,
    "groupIcon": 4640486,
    "id": "DragonRiding",
    "information": {
      "groupOffset": false
    },
    "internalVersion": 84,
    "load": {
      "class": {
        "multi": []
      },
      "size": {
        "multi": []
      },
      "spec": {
        "multi": []
      },
      "talent": {
        "multi": []
      }
    },
    "regionType": "group",
    "scale": 1,
    "selfPoint": "CENTER",
    "semver": "1.0.52",
    "source": "import",
    "subRegions": [],
    "tocversion": 110105,
    "triggers": [
      {
        "trigger": {
          "debuffType": "HELPFUL",
          "event": "Health",
          "names": [],
          "spellIds": [],
          "subeventPrefix": "SPELL",
          "subeventSuffix": "_CAST_START",
          "type": "aura2",
          "unit": "player"
        },
        "untrigger": []
      }
    ],
    "uid": "Xm41iP7HyJ(",
    "url": "https://wago.io/x5C6gaJRB/53",
    "version": 53,
    "wagoID": "x5C6gaJRB",
    "xOffset": 0,
    "yOffset": -235
  },
  "m": "d",
  "s": "5.19.9",
  "v": 2000,
  "wagoID": "x5C6gaJRB"
}