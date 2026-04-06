require_relative 'e2e_helper'

RSpec.describe 'Registration', type: :e2e do
  include_context 'bot e2e'

  describe 'new user sends /start' do
    it 'creates the user in the database' do
      expect { receive(tg_user, text: '/start') }
        .to change(User, :count).by(1)
    end

    it 'sends the welcome greeting with the user name' do
      msgs = receive(tg_user, text: '/start')
      expect(msgs.last[:text]).to include('Anya')
    end

    it 'does not create a duplicate user on a second /start' do
      receive(tg_user, text: '/start')
      expect { receive(tg_user, text: '/start') }.not_to change(User, :count)
    end
  end
end
