class AppointmentsController < ApplicationController
  
  require 'rubygems'
  require 'twilio-ruby'
  
  def create_appointment(start, finish, full_name, email)
    # Create appointment for schedule
    values = "schedule_id=279543&password=#{ENV['SUPERSAAS_PASSWPRD']}&booking[start]=#{start}&booking[finish]=#{finish}&booking[full_name]=#{full_name}&booking[email]=#{email}"
    RestClient.post("http://www.supersaas.com/api/bookings?#{values}",  {}, :content_type => "application/json", :accept => "application/json")
  end
  
  def message_callback
  	begin
    message, phone_number = params['Body'], params['From']
    
    #Check if user is registered or not
    user, user_present = check_user(phone_number.split(//).last(10).join)
    
    #Create twillio client to deal with twillio APIs
    get_client
    if user_present
      events, reply = get_events
      if message == "PUCK"
        #Send list of upcouming 3 events
        @client.messages.create(
          from: '+19253388043',
          to: phone_number,
          body: reply
        )
        logger.warn "List of events sent"
      elsif ["1", "2", "3"].include? message
      	index = params[:Body].to_i - 1
        event = events[index]
        
        #Create appointment according to the reply
        create_appointment(event['start'], event['finish'], user['full_name'], user['name'])
        reply = "You are registered in this event #{event['title']} #{event['start']}-#{event['finish']}"
        @client.messages.create(
          from: '+19253388043',
          to: phone_number,
          body: reply
        )
        logger.warn "Event booked"
      end
    else
      #Send registration url if not registered.
      reply = "You are not registered. Please register here http://www.supersaas.com/users/new/enbake?after=%2Fschedule%2Fenbake%2Ftest_schedule&return=%2Fschedule%2Flogin%2Fenbake%2Ftest_schedule%3Fafter%3D%252Fschedule%252Fenbake%252Ftest_schedule"
      @client.messages.create(
        from: '+19253388043',
        to: phone_number,
        body: reply
      )
      logger.warn "Registration link sent"
    end
      render :text => "Success"
    rescue Exception => e
      @client.messages.create(
        from: '+19253388043',
        to: params['From'],
        body: "Some error occured. Please try again"
      )
      logger.warn e.message
      render :text => "Success"
    end
  end
  
  def get_client
    account_sid = ENV['ACCOUNT_SID']
    auth_token = ENV['ACCOUNT_TOEKN']
    
    # set up a client to talk to the Twilio REST API
    @client = Twilio::REST::Client.new account_sid, auth_token
    
    # alternatively, you can preconfigure the client like so
    Twilio.configure do |config|
      config.account_sid = account_sid
      config.auth_token = auth_token
    end
    
    # and then you can create a new client without parameters
    @client = Twilio::REST::Client.new
  end
  
  def check_user(phone_number)
  	resp = RestClient.get( "http://www.supersaas.com/api/users?account=enbake&password=enbake123", :content_type => "application/json", :accept => "application/json")
  	users = JSON.parse(resp)
  	user_present, user = false, nil
  	users.each {|u| (user_present, user = true, u) if u['phone'] == phone_number}
  	return user, user_present
  end
  
  def get_events
  	resp = RestClient.get( 'http://www.supersaas.com/api/free/279543.xml?from=2016-05-05 12:24:23&password=enbake123', :content_type => "application/json", :accept => "application/json")
    json_resp = Hash.from_xml(resp)
    events = json_resp['slots']['slot'].first(3)
    message = ""
    events.each_with_index {|e,i| message.concat"#{i+1}. #{e['title']} #{e['start']}-#{e['finish']}".concat"\n"}
    return events, message
  end
end
