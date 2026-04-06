require_relative 'e2e_helper'

RSpec.describe 'Daily reminder', type: :e2e do
  include_context 'bot e2e'

  before { receive(tg_user, text: '/start') }

  it 'saves the reminder after providing time and days' do
    user = User.find_by(telegram_id: tg_user[:id])

    receive(tg_user, text: MSGS[:btn_reminder])
    receive(tg_user, text: '09:00')

    expect {
      receive(tg_user, text: 'все')
    }.to change(Reminder, :count).by(1)

    reminder = Reminder.find_by(user: user)
    expect(reminder.time).to eq('09:00')
    expect(reminder.days.length).to eq(7)
  end

  it 'sends confirmation with the set time' do
    receive(tg_user, text: MSGS[:btn_reminder])
    receive(tg_user, text: '18:30')
    msgs = receive(tg_user, text: 'будни')
    expect(msgs.last[:text]).to include('18:30')
  end

  it 'rejects an invalid time format' do
    receive(tg_user, text: MSGS[:btn_reminder])
    msgs = receive(tg_user, text: 'nine o clock')
    expect(msgs.last[:text]).to eq(MSGS[:reminder_bad_time])
  end

  it 'rejects invalid days' do
    receive(tg_user, text: MSGS[:btn_reminder])
    receive(tg_user, text: '10:00')
    msgs = receive(tg_user, text: 'whenever')
    expect(msgs.last[:text]).to eq(MSGS[:reminder_bad_days])
  end

  it 'updates an existing reminder instead of creating a duplicate' do
    receive(tg_user, text: MSGS[:btn_reminder])
    receive(tg_user, text: '08:00')
    receive(tg_user, text: 'все')

    receive(tg_user, text: MSGS[:btn_reminder])
    receive(tg_user, text: '20:00')

    expect {
      receive(tg_user, text: 'выходные')
    }.not_to change(Reminder, :count)

    user = User.find_by(telegram_id: tg_user[:id])
    expect(Reminder.find_by(user: user).time).to eq('20:00')
  end
end
