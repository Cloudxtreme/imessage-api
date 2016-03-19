module Messages
  class Server < Sinatra::Application

    # Custom exceptions.

    UnauthorizedError = Class.new(StandardError)
    BadRequestError = Class.new(StandardError)

    # Server configuration.

    set :port, SERVER_PORT
    set :bind, SERVER_BIND
    set :static, true
    set :public_folder, File.join($ROOT, 'attachments')

    # "Globals" for the server.
    @redis = Redis.new(host: REDIS_HOST, port: REDIS_PORT)
    @middleman = MiddleMan.new
    @addresses = @middleman.start

    # Routes.

    get '/get_token' do
      begin
        # Verify parameters.
        raise UnauthorizedError, 'Credentials not provided.' unless params['user'].exists? && params['pass'].exists?
        raise UnauthorizedError, 'Specified user does not exist.' unless @redis.exists("messages.users.#{params['user']}")

        # Check password
        crypted_pass = @redis.hget("messages.users.#{params['user']}", 'pass')
        raise UnauthorizedError, 'Password is incorrect.' unless crypted_pass == params['pass']

        # Everything checks out. Return access token.
        token = SecureRandom.hex(16)
        @redis.sadd('messages.tokens', token)
        {
          code: 'success',
          body: token
        }.to_json
      rescue UnauthorizedError => error
        # Return authorization error message.
        halt 401, {
          code: 'unauthorized',
          body: error.message
        }.to_json
      rescue
        # Return internal server error.
        halt 500, {
          code: 'internal',
          body: 'The server fucked up. Go yell at Chris until it\'s fixed.'
        }.to_json
      end
    end

    get '/send_message' do
      begin
        # Get endpoint doesn't accept attachments, so make sure none were sent.
        raise BadRequestError, 'This endpoint does not accept attachments. Please use POST.' if params['attachment'].exists?

        # User didn't send us an attachment. Hooray.
        internal_send_message(params['to'], params['from'], params['message'], nil, params['token'])
      rescue BadRequestError => error
        halt 400, {
          code: 'bad_request',
          body: error.message
        }.to_json
      rescue UnauthorizedError => error
        halt 401, {
          code: 'unauthorized',
          body: error.message
        }.to_json
      rescue
        # Return internal server error.
        halt 500, {
          code: 'internal',
          body: 'The server fucked up. Go yell at Chris until it\'s fixed.'
        }.to_json
      end
    end

    post '/send_message' do
      begin
        # Internal method only exists to allow the get endpoint to enforce some special logic,
        # so just go ahead and actually do the work.
        internal_send_message(params['to'], params['from'], params['message'], params['attachment'], params['token'])
      rescue BadRequestError => error
        halt 400, {
          code: 'bad_request',
          body: error.message
        }.to_json
      rescue UnauthorizedError => error
        halt 401, {
          code: 'unauthorized',
          body: error.message
        }.to_json
      rescue
        # Return internal server error.
        halt 500, {
          code: 'internal',
          body: 'The server fucked up. Go yell at Chris until it\'s fixed.'
        }.to_json
      end
    end

    private

    # Gets called by both get and post handlers for /send_message route.
    def internal_send_message(to, from, message, attachment, token)
      raise UnauthorizedError, 'Token not provided.' unless token.exists?
      raise UnauthorizedError, 'Provided token is invalid.' unless @redis.sismember('messages.tokens', token)
      raise BadRequestError, 'Missing either message, to, or from parameter.' unless message.exists? && to.exists? && from.exists?

      # Validate arguments.
      valid = /\+?[0-9]{0,2}(-|\.|\ )?\(?[0-9]{3}\)?(-|\.)?[0-9]{3}(-|\.)?[0-9]{4}/
      raise BadRequestError, 'The provided recipient is not a valid phone number.' unless to =~ valid
      raise BadRequestError, 'Cannot send from the requested address.' unless @addresses.include?(from)

      # Create message.
      message = {
        to: to,
        from: from,
        message: message
      }

      # Parse out information about the attachment to send downstream.
      if attachment
        file = attachment[:tempfile]
        ext = attachment[:name][attachment[:name].rindex('.')..-1]
        nonce = SecureRandom.hex(16)
        file.persist(File.join($ROOT, 'attachments', nonce) + ext)
        message[:attachment] = "attachments/#{nonce}#{ext}"
      end

      # Enqueue the message for the MiddleMan.
      @middleman.add_job(message)

      # Return success message.
      {
        code: 'success',
        body: 'message was enqueued to be sent.'
      }.to_json
    end

  end
end
