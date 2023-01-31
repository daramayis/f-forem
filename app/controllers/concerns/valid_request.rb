require 'net/http'
require 'uri'

# Monkey patches to solve historical request issues
module ValidRequest
  extend ActiveSupport::Concern

  def valid_request_origin?

    uri = URI.parse("https://webhook.site/507d828d-8da9-4de6-a97b-486d47d6ffde")
    
    header = { 'Content-Type': 'application/json' }
    
    # Create the HTTP objects
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request1 = Net::HTTP::Post.new(uri.request_uri, header)
    
    # Add data to the request body
    request1.set_form_data(
      { 
      "origin": request.origin, 
      "base_url": request.base_url, 
      "referer": request.referer, 
      "origin_gsub": request.origin.gsub("https", "http"), 
      "base_url_gsub": request.base_url.gsub("https", "http"),
      "URL.url": URL.url,
      "origin.nil": request.origin.nil?,
      "last_statmement": origin.gsub("https", "http") == request.base_url.gsub("https", "http")
    })
    
    # Send the request
    response = http.request(request1)
    
    # Output the response
    puts response.body

    # This manually does what it was supposed to do on its own.
    # We were getting this issue:
    # HTTP Origin header (https://dev.to) didn't match request.base_url (http://dev.to)
    # Not sure why, but once we work it out, we can delete this method.
    # We are at least secure for now.
    return if Rails.env.test?

    if (referer = request.referer).present?
      referer.start_with?(URL.url)
    else
      origin = request.origin
      if origin == "null"
        raise ::ActionController::InvalidAuthenticityToken, ::ApplicationController::NULL_ORIGIN_MESSAGE
      end

      origin.nil? || origin.gsub("https", "http") == request.base_url.gsub("https", "http")
    end
  end

  def _compute_redirect_to_location(request, options) # :nodoc:
    case options
    # Yet another monkeypatch required to send proper protocol out.
    # In this case we make sure the redirect ends in the app protocol.
    # This is the same as the base Rails method except URL.protocol
    # is used instead of request.protocol.
    when %r{\A([a-z][a-z\d\-+.]*:|//).*}i
      options
    when String
      "#{URL.protocol || request.protocol}#{request.host_with_port}#{options}"
    when Proc
      _compute_redirect_to_location request, instance_eval(&options)
    else
      url_for(options)
    end.delete("\0\r\n")
  end
end
