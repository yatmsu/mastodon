require 'rails_helper'

RSpec.describe NotifyService do
  subject do
    -> { described_class.new.call(recipient, activity) }
  end

  let(:user) { Fabricate(:user) }
  let(:recipient) { user.account }
  let(:sender) { Fabricate(:account) }
  let(:activity) { Fabricate(:follow, account: sender, target_account: recipient) }

  it { is_expected.to change(Notification, :count).by(1) }

  it 'does not notify when sender is blocked' do
    recipient.block!(sender)
    is_expected.to_not change(Notification, :count)
  end

  it 'does not notify when sender is silenced and not followed' do
    sender.update(silenced: true)
    is_expected.to_not change(Notification, :count)
  end

  it 'does not notify when recipient is suspended' do
    recipient.update(suspended: true)
    is_expected.to_not change(Notification, :count)
  end

  context do
    let(:asshole)  { Fabricate(:account, username: 'asshole') }
    let(:reply_to) { Fabricate(:status, account: asshole) }
    let(:activity) { Fabricate(:mention, account: recipient, status: Fabricate(:status, account: sender, thread: reply_to)) }

    it 'does not notify when conversation is muted' do
      recipient.mute_conversation!(activity.status.conversation)
      is_expected.to_not change(Notification, :count)
    end

    it 'does not notify when it is a reply to a blocked user' do
      recipient.block!(asshole)
      is_expected.to_not change(Notification, :count)
    end
  end

  context do
    let(:sender) { recipient }

    it 'does not notify when recipient is the sender' do
      is_expected.to_not change(Notification, :count)
    end
  end

  describe 'email' do
    before do
      ActionMailer::Base.deliveries.clear

      notification_emails = user.settings.notification_emails
      user.settings.notification_emails = notification_emails.merge('follow' => enabled)
    end

    context 'when email notification is enabled' do
      let(:enabled) { true }

      it 'sends email' do
        is_expected.to change(ActionMailer::Base.deliveries, :count).by(1)
      end
    end

    context 'when email notification is disabled' do
      let(:enabled) { false }

      it "doesn't send email" do
        is_expected.to_not change(ActionMailer::Base.deliveries, :count).from(0)
      end
    end
  end
end
