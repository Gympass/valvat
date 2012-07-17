require 'valvat'
require 'net/http'
require 'yaml'

class Valvat
  module Lookup

    def self.validate(vat, options={})
      vat = Valvat(vat)
      return false unless vat.european?

      request = options[:requester_vat] ? 
        Valvat::Lookup::RequestWithId.new(vat, Valvat(options[:requester_vat])) : 
        Valvat::Lookup::Request.new(vat)
      
      begin
        response = request.perform(self.client)
        response[:valid] && (options[:detail] || options[:requester_vat]) ? 
          filter_detail(response) : response[:valid]
      rescue => err
        @last_error = err
        if err.respond_to?(:to_hash) && err.to_hash[:fault] && err.to_hash[:fault][:faultstring] == "{ 'INVALID_INPUT' }"
          return false
        end
        nil
      end
    end

    def self.client
      @client ||= begin
        # Require Savon only if really needed!
        require 'savon' unless defined?(Savon)

        # Quiet down Savon and HTTPI
        Savon.logger.level = Logger::WARN
        HTTPI.logger.level = Logger::WARN

        Savon::Client.new do
          wsdl.document = 'http://ec.europa.eu/taxation_customs/vies/checkVatService.wsdl'
        end
      end
    end
    
    def self.last_error
      @last_error
    end
    
    private
    
    REMOVE_KEYS = [:valid, :@xmlns] 
    
    def self.filter_detail(response)
      response.inject({}) do |hash, kv|
        key, value = kv
        unless REMOVE_KEYS.include?(key)
          hash[key.to_s.sub(/^trader_/, "").to_sym] = (value == "---" ? nil : value)
        end
        hash
      end
    end
  end
end
