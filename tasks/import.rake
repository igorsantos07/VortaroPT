# -*- encoding : utf-8 -*-
namespace :import do
  pe = ('a'..'z').to_a << '00'
  ep = ('a'..'z').to_a << 'ch' << 'gh' << 'hh' << 'jh' << 'sh' << 'uh' << '00'
  parts = {:pe => pe, :ep => ep}

  desc 'Will import all the pages, splitting data between "word" and "meaning" only'
  task :simple do
    pp parts
  end

  desc 'Tries to split "word" and all complex parts of the "meaning"'
  task :complex do
    require 'open-uri'

    $: << './eoparser'
    require 'Parser'

    parts.each do |part, letters|
      letters.each do |letter|
        url = "http://vortaro.brazilo.org/vtf/dic/#{part}_#{letter}.htm"
        puts "Going to #{url}"
        page = Nokogiri::HTML(open(url)) { |c| c.noent.noblanks }
        page.css('div p').each do |node|
          word_nodeset = node.css('b:first-child')
          if word_nodeset[0]
            word = word_nodeset[0].text
            data = node.children - word_nodeset
            info = {:other => []}

            ##
            # FIRST TAG [meaning, origin, synonym]

            first_tag = data.first.name
            # word meaning
            if first_tag == 'i'
              text = data.first.text
              if (type = text.match /^(\w+\.\w+\.|\w+\.)/)
                info[:type] = type[0].strip
                text = text[(type[0].length)..-1]
              end
              info[:meaning] = text.strip unless text.strip.empty?

            # other kind of content, need to investigate further
            elsif first_tag == 'span'
              string = data.first.text.strip
              # origin or alternative lecture (?)
              if (origin = string.match(/^\[([\w\s]*)\]$/))
                info[:origin] = origin[1].strip

              # is a synonym of
              elsif (synonym = string.match(/^=(.*)/))
                info[:synonym] = synonym[1].strip
              end

            # what the hell is this??
            else
              puts "######## #{data.first.text.strip}"
              info[:other] << data.first.text.strip
            end

            if info[:type].nil?
              best_meaning, highest_match = nil, -1

              EO::Parser.parse(word).each do |meaning|
                if meaning.validity > highest_match
                  highest_match = meaning.validity
                  best_meaning = meaning
                end
              end

              type = (best_meaning.nil?)? nil : best_meaning.pos
              info[:type] = case type
                when 'v'    then 'verbo'
                when 'n'    then 'substantivo'
                when 'adj'  then 'adjetivo'
                when 'adv'  then 'advérbio'
                when nil    then 'nome próprio'
                else        type
              end
            end


            ##
            # SECOND TAG [meaning yet, or translation]
            second_tag = data[1].name
            second_text = data[1].text.strip.sub /\r\n/, ''

            # word meaning (probably the first tag was 'origin')
            if second_tag == 'i'
              if info[:meaning].nil?
                info[:meaning] = second_text
              else
                info[:meaning] = [info[:meaning], second_text]
              end

            # synonym
            elsif (synonym = second_text.match(/^=(.*)/))
              puts second_text
              info[:synonym] = synonym[1].strip.chomp('.')

            # the translation
            else
              info[:translation] = second_text
            end



            if info[:other].empty? then info.delete(:other) end
            puts word
#           puts data
            pp info
            puts ''
            puts ''
          end
        end
      end
    end
  end
end