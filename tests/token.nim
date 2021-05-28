import os
import strutils

var token*: string = ""
if "token".fileExists():
    token = readFile("token").strip()
else:
    token = getEnv("DISCORDTOKEN").strip()