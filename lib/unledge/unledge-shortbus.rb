#!/usr/bin/env ruby

# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.

require 'shortbus'
require 'unledge/unledge'

# Regular expression to match an irc nick pattern (:nick[!user@host])
# and capture the nick portion in \1
NICKRE = /^:([^!]*)!.*/

# Match beanfootage's tinyurl output
TINYURL_REGEX = /^(:)?\[AKA\]/

MAX_MESSAGE_LENGTH = 1024
UNLEDGE_PREFIX_RE = /^T(wee|oo)t:/

# ShortBus plugin to name/shame url reposters
module Unledge
  class UnledgeShortBus < ShortBus::ShortBus
    # Constructor
    def initialize()
      super

      # Expression to match an action/emote message
      @ACTION = /^\001ACTION(.*)\001/

      @unledge = Unledge.new()
      @channels = []
      @hooks = []
      hook_command( 'UNLEDGE', ShortBus::XCHAT_PRI_NORM, method( :enable), '')
      hook_server( 'Disconnected', ShortBus::XCHAT_PRI_NORM, method( :disable))
      hook_server( 'Notice', ShortBus::XCHAT_PRI_NORM, method( :notice_handler))
      puts('Unledge loaded. Run /UNLEDGE #channel to enable.')
    end # initialize

    # Enables the plugin
    def enable(words, words_eol, data)
      if (words.size < 2)
        if (@hooks.empty?)
          puts('Usage: UNLEDGE #channel [channel2 ...]')
          return ShortBus::XCHAT_EAT_ALL
        else
          disable()
        end
      end

      begin
        if ([] == @hooks)
          @hooks << hook_server('PRIVMSG', ShortBus::XCHAT_PRI_NORM, method(:process_message))
          @hooks << hook_print('Your Message', ShortBus::XCHAT_PRI_NORM, method(:your_message))
          @hooks << hook_print('Your Action', ShortBus::XCHAT_PRI_NORM, method(:your_action))
        end

        1.upto(words.size-1){ |i|
          if (@channels.select{ |item| item == words[i] }.empty?)
            @channels << words[i]
            puts("Monitoring #{words[i]}")
          else
            @channels -= [words[i]]
            puts("Ignoring #{words[i]}")
          end
        }
      rescue
        # puts("#{caller.first}: #{$!}")
      end

      return ShortBus::XCHAT_EAT_ALL
    end # enable

    # Disables the plugin
    def disable(words=nil, words_eol=nil, data=nil)
      begin
        if (@hooks.empty?)
          puts('Unledge already disabled.')
        else
          @hooks.each{ |hook| unhook(hook) }
          @hooks = []
          dump(nil, nil, nil)
          puts('Unledge disabled.')
        end
      rescue
        # puts("#{caller.first}: #{$!}")
      end

      return ShortBus::XCHAT_EAT_ALL
    end # disable

    # Check for disconnect notice
    def notice_handler(words, words_eol, data)
      begin
        if (words_eol[0].match(/(^Disconnected|Lost connection to server)/))
          disable()
        end
      rescue
        # puts("#{caller.first}: #{$!}")
      end

      return ShortBus::XCHAT_EAT_NONE
    end # notice_handler

    # Processes outgoing actions
    # (Really formats the data and hands it to process_message())
    # * param words [Mynick, mymessage]
    # * param data Unused
    # * returns ShortBus::XCHAT_EAT_NONE
    def your_action(words, data)
      words[1] = "\001ACTION#{words[1]}\001"
      return your_message(words, data)
    end # your_action

    # Processes outgoing messages
    # (Really formats the data and hands it to process_message())
    # * param words [Mynick, mymessage]
    # * param data Unused
    # * returns ShortBus::XCHAT_EAT_NONE
    def your_message(words, data)
      rv = ShortBus::XCHAT_EAT_NONE

      begin
        channel = get_info('channel')
        # Don't catch the outgoing "Tweet: meh"
        if (UNLEDGE_PREFIX_RE.match(words[1]) || !@channels.detect{ |item| item == channel }) then return ShortBus::XCHAT_EAT_NONE; end

        words_eol = []
        # Build an array of the format process_message expects
        newwords = [words[0], 'PRIVMSG', channel] + (words - [words[0]])

        # puts("Outgoing message: #{words.join(' ')}")

        # Populate words_eol
        1.upto(newwords.size){ |i|
          words_eol << (i..newwords.size).inject(''){ |str, j|
            "#{str}#{newwords[j-1]} "
          }.strip()
        }

        rv = process_message(newwords, words_eol, data)
      rescue
        # puts("#{caller.first}: #{$!}")
      end

      return rv
    end # your_message

    # Processes an incoming server message
    # * words[0] -> ':' + user that sent the text
    # * words[1] -> PRIVMSG
    # * words[2] -> channel
    # * words[3..(words.size-1)] -> ':' + text
    # * words_eol is the joining of each array of words[i..words.size]
    # * (e.g. ["all the words", "the words", "words"]
    def process_message(words, words_eol, data)
      begin
        sometext = ''
        outtext = ''
        nick = words[0].sub(NICKRE,'\1')
        storekey = nil
        index = 0
        line = nil
        channel = words[2]

        # Strip intermittent trailing @ word
        if (words.last == '@')
          words.pop()
          words_eol.collect!{ |w| w.gsub(/\s+@$/,'') }
        end

        if (!@channels.detect{ |item| item == channel } ||
            words_eol.size < 4 ||
            words_eol[3].match(TINYURL_REGEX))
          return ShortBus::XCHAT_EAT_NONE
        end

        # puts("Processing message: #{words_eol[3]}")

        response = @unledge.process_statement(words_eol[3])

        # puts("Response #{response}")

        if (response)
          command("MSG #{channel} #{UnledgeShortBus.ellipsize(response)}")
        end
      rescue
        puts("#{caller.first}: #{$!}")
      end

      return ShortBus::XCHAT_EAT_NONE
    end # process_message

    def UnledgeShortBus.ellipsize(str)
      (MAX_MESSAGE_LENGTH < str.size) ?
        "#{str.slice(0, MAX_MESSAGE_LENGTH)}..." :
        str
    end # ellipsize
  end # UnledgeShortBus
end # Unledge
