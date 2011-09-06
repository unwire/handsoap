# -*- coding: utf-8 -*-
require 'rubygems'
require 'test/unit'

$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__) + "/../lib")
require 'handsoap'

ACCOUNT_SERVICE_ENDPOINT = {
  :uri => 'http://ws.example.org/',
  :version => 1
}

class AccountService < Handsoap::Service
  endpoint ACCOUNT_SERVICE_ENDPOINT

  def on_create_document(doc)
    doc.alias 'tns', 'http://schema.example.org/AccountService'
    doc.alias 's', "http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd"
    header = doc.find("Header")
    header.add "s:Security" do |s|
      s.set_attr "env:mustUnderstand", "0"
      s.add "s:Username", @@username
    end
  end

  def on_response_document(doc)
    # register namespaces for the response
    doc.add_namespace 'ns', 'http://schema.example.org/AccountService'
  end

  @@username = ""
  def self.username=(username)
    @@username = username
  end

  # public methods

  def get_account_by_id(account_id)
    soap_action = 'http://ws.example.org/AccountService/GetAccountById'
    response = invoke('tns:GetAccountById', soap_action) do |message|
      message.add 'account-id', account_id
    end
    # <ns1:GetAccountByIdResponse xmlns:ns1="http://schema.example.org/AccountService">
    #   <account msisdn="4560140026" created="2008-11-20T16:53:48.000+01:00" buy-attempts="79" blacklisted="false" application-id="1" amount-used="304650" account-id="1"/
    (response.document/"//ns:GetAccountByIdResponse/account").map{|node| parse_account(node) }.first
  end

  private
  # helpers

  def parse_account(node)
    # <account msisdn="4560140026" created="2008-11-20T16:53:48.000+01:00" buy-attempts="79" blacklisted="false" application-id="1" amount-used="304650" account-id="1"/>
    Account.new :msisdn => (node/"@msisdn").to_s,
                :created => (node/"@created").to_date,
                :buy_attempts => (node/"@buy-attempts").to_i,
                :blacklisted => (node/"@blacklisted").to_boolean,
                :application_id => (node/"@application-id").to_i,
                :amount_used => (node/"@amount-used").to_i,
                :account_id => (node/"@account-id").to_i,
                :credit => (node/"@credit").to_big_decimal
  end
end

class Account
  attr_accessor :msisdn, :application_id, :account_id, :created, :buy_attempts, :amount_used
  attr_writer :blacklisted
  def initialize(values = {})
    @msisdn = values[:msisdn]
    @application_id = values[:application_id]
    @account_id = values[:account_id]
    @created = values[:created]
    @buy_attempts = values[:buy_attempts]
    @blacklisted = values[:blacklisted] || false
    @amount_used = values[:amount_used]
    @credit = values[:credit]
  end
  def blacklisted?
    !! @blacklisted
  end
end


class AccountServiceTest < Test::Unit::TestCase

  def setup
    # AccountService.logger = $stdout
    AccountService.username = "someone"
    headers = 'Date: Fri, 14 Aug 2009 11:57:36 GMT
Content-Type: text/xml;charset=UTF-8
X-Powered-By: Servlet 2.4; JBoss-4.2.2.GA (build: SVNTag=JBoss_4_2_2_GA date=200710221139)/Tomcat-5.5
Server: Apache-Coyote/1.1'.gsub(/\n/, "\r\n")
    body = '<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <ns1:GetAccountByIdResponse xmlns:ns1="http://schema.example.org/AccountService">
      <account msisdn="12345678" account-id="1" created="2009-08-03T11:28:26+02:00" buy-attempts="42" blacklisted="true" application-id="1" amount-used="123456" credit="24.95"/>
    </ns1:GetAccountByIdResponse>
  </soap:Body>
</soap:Envelope>'
    Handsoap::Http.drivers[:mock] = Handsoap::Http::Drivers::MockDriver.new :headers => headers, :content => body, :status => 200
    Handsoap.http_driver = :mock
  end

  def test_get_account_by_id
    driver = Handsoap::Http.drivers[:mock].new # passthrough, doesn’t actually create a new instance
    result = AccountService.get_account_by_id(10)
    assert_equal 'http://ws.example.org/', driver.last_request.url
    assert_equal :post, driver.last_request.http_method
    assert_kind_of Account, result
  end
end
