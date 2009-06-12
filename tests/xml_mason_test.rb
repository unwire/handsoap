# -*- coding: utf-8 -*-
$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'handsoap/xml_mason'

doc = Handsoap::XmlMason::Document.new do |doc|
  doc.alias 'env', "http://www.w3.org/2003/05/soap-envelope"
  doc.alias 'm', "http://travelcompany.example.org/reservation"
  doc.alias 'n', "http://mycompany.example.com/employees"
  doc.alias 'p', "http://travelcompany.example.org/reservation/travel"
  doc.alias 'q', "http://travelcompany.example.org/reservation/hotels"

  doc.add "env:Envelope" do |env|
    env.add "Header" do |header|
      header.add 'm:reservation' do |r|
        r.set_attr 'env:role', "http://www.w3.org/2003/05/soap-envelope/role/next"
        r.set_attr 'env:mustUnderstand', "true"
        r.add 'reference', "uuid:093a2da1-q345-739r-ba5d-pqff98fe8j7d"
        r.add 'dateAndTime', "2001-11-29T13:20:00.000-05:00"
      end
      header.add 'n:passenger' do |p|
        p.set_attr 'env:role', "http://www.w3.org/2003/05/soap-envelope/role/next"
        p.set_attr 'env:mustUnderstand', "true"
        p.add 'name', "Åke Jógvan Øyvind"
      end
    end
    env.add "Body" do |body|
      body.add 'p:itinerary' do |i|
        i.add 'departure' do |d|
          d.add 'departing', "New York"
          d.add 'arriving', "Los Angeles"
          d.add 'departureDate', "2001-12-14"
          d.add 'departureTime', "late afternoon"
          d.add 'seatPreference', "aisle"
        end
        i.add 'return' do |r|
          r.add 'departing', "Los Angeles"
          r.add 'arriving', "New York"
          r.add 'departureDate', "2001-12-20"
          r.add 'departureTime', "mid-morning"
          r.add 'seatPreference'
        end
      end
      body.add 'q:lodging' do |l|
        l.add 'preference', "none"
      end
    end
  end
end

puts doc
# puts doc.find("Body")
# puts doc.find_all("departureTime")

doc = Handsoap::XmlMason::Document.new do |doc|
  doc.add 'body' do |b|
    b.add 'yonks', "lorem\nipsum\ndolor\nsit amet"
  end
end

puts doc

x = nil
doc = Handsoap::XmlMason::Document.new do |doc|
  doc.add 'body' do |b|
    b.add 'yonks', "lorem\nipsum\ndolor\nsit amet"
    b.add 'ninja' do |n|
      x = n
      n.set_value "ninja"
    end
    b.add 'ninjitsu' do |n|
      n.set_value "ninjitsu"
    end
  end
end

puts "-------------"
p x.document.find('ninjitsu').to_s

puts "-------------"
p x.document.find(:ninjitsu).to_s

puts "-------------"

doc = Handsoap::XmlMason::Document.new do |doc|
  doc.add 'body' do |b|
    b.add 'raw' do |y|
      y.set_value '<b>bold</b>', :raw
    end
    b.add 'well-done' do |y|
      y.set_value '<b>bold</b>'
    end
  end
end

puts doc
