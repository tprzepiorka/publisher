require 'integration_test_helper'

class FactCheckEmailTest < ActionDispatch::IntegrationTest
  def fact_check_mail_for(edition, attrs = {})
    message = Mail.new do
      from    attrs.fetch(:from,    'foo@example.com')
      to      attrs.fetch(:to,      edition && edition.fact_check_email_address)
      cc      attrs.fetch(:cc,      nil)
      bcc     attrs.fetch(:bcc,     nil)
      subject attrs.fetch(:subject, "This is a fact check response")
      body    attrs.fetch(:body,    'I like it. Good work!')
    end

    # The Mail.all(:delete_after_find => true) call in FactCheckEmailHandler will set this
    # on all messages before yielding them
    message.mark_for_delete= true
    message
  end

  test "should pick up an email and add an action to the edition, and advance the state to 'fact_check_received'" do
    answer = FactoryGirl.create(:answer_edition, :state => 'fact_check')

    message = fact_check_mail_for(answer)
    Mail.stubs(:all).yields( message )

    handler = FactCheckEmailHandler.new
    handler.process

    answer.reload
    assert answer.fact_check_received?

    action = answer.actions.last
    assert_equal "I like it. Good work!", action.comment
    assert_equal "receive_fact_check", action.request_type

    assert message.is_marked_for_delete?
  end

  test "should pick up an email and add an action to the edition, even if it's not in 'fact_check' state" do
    answer = FactoryGirl.create(:answer_edition, :state => 'fact_check_received')

    Mail.stubs(:all).yields( fact_check_mail_for(answer) )

    handler = FactCheckEmailHandler.new
    handler.process

    answer.reload
    assert answer.fact_check_received?

    action = answer.actions.last
    assert_equal "I like it. Good work!", action.comment
    assert_equal "receive_fact_check", action.request_type
  end

  test "should pick up multiple emails and update the relevant publications" do
    answer1 = FactoryGirl.create(:answer_edition, :state => 'fact_check')
    answer2 = FactoryGirl.create(:answer_edition, :state => 'in_review')

    Mail.stubs(:all).multiple_yields(
          fact_check_mail_for(answer1, :body => "First Message"),
          fact_check_mail_for(answer2, :body => "Second Message"),
          fact_check_mail_for(answer1, :body => "Third Message")
    )

    handler = FactCheckEmailHandler.new
    handler.process

    answer1.reload
    assert answer1.fact_check_received?
    answer2.reload
    assert answer2.in_review?

    action = answer1.actions[-2]
    assert_equal "First Message", action.comment
    assert_equal "receive_fact_check", action.request_type

    action = answer1.actions[-1]
    assert_equal "Third Message", action.comment
    assert_equal "receive_fact_check", action.request_type

    action = answer2.actions[-1]
    assert_equal "Second Message", action.comment
    assert_equal "receive_fact_check", action.request_type
  end

  test "should ignore and not delete messages with a non-expected recipient address" do

    message = fact_check_mail_for(nil, :to => "something@example.com")

    Mail.stubs(:all).yields(message)

    handler = FactCheckEmailHandler.new
    handler.process

    assert ! message.is_marked_for_delete?
  end

  test "should look for fact-check address cc or bcc fields" do
    edition_cc = FactoryGirl.create(:answer_edition, :state => 'fact_check')
    # Test that it ignores irrelevant recipients
    message_cc  = fact_check_mail_for(edition_cc, to: "something@example.com", cc: edition_cc.fact_check_email_address)

    edition_bcc = FactoryGirl.create(:answer_edition, :state => 'fact_check')
    # Test that it doesn't fail on a nil recipient field
    message_bcc = fact_check_mail_for(edition_bcc, to: nil, bcc: edition_bcc.fact_check_email_address)

    Mail.stubs(:all).multiple_yields(message_cc, message_bcc)

    handler = FactCheckEmailHandler.new
    handler.process

    assert message_cc.is_marked_for_delete?
    assert message_bcc.is_marked_for_delete?
  end

  test "should invoke the supplied block after each message" do
    answer1 = FactoryGirl.create(:answer_edition, :state => 'fact_check')
    answer2 = FactoryGirl.create(:answer_edition, :state => 'in_review')

    Mail.stubs(:all).multiple_yields(
          fact_check_mail_for(answer1, :body => "First Message"),
          fact_check_mail_for(answer2, :body => "Second Message")
    )

    handler = FactCheckEmailHandler.new

    invocations = 0
    handler.process do
      invocations += 1
    end

    assert_equal 2, invocations
  end

  context "Out of office replies" do
    def assert_answer_progresses_to_fact_check_received(header)
      assert_correct_state(header, "fact_check_received")
    end

    def assert_answer_still_in_fact_check_state(out_of_office_header)
      assert_correct_state(out_of_office_header, "fact_check")
    end

    def assert_correct_state(header_hash, state)
      answer = FactoryGirl.create(:answer_edition, :state => 'fact_check')
      message = fact_check_mail_for(answer)
      message[header_hash.keys.first] = header_hash.values.first

      Mail.stubs(:all).yields( message )
      FactCheckEmailHandler.new.process

      answer.reload
      assert answer.public_send("#{state}?")
    end

    [
      ['Auto-Submitted', 'auto-replied'],
      ['Auto-Submitted', 'auto-generated'],
      ['Precedence', 'bulk'],
      ['Precedence', 'auto_reply'],
      ['Precedence', 'junk'],
      ['Return-Path', nil],
      ['Subject', 'Out of Office'],
      ['X-Precedence', 'bulk'],
      ['X-Precedence', 'auto_reply'],
      ['X-Precedence', 'junk'],
      ['X-Autoreply', 'yes'],
      ['X-Autorespond', nil],
      ['X-Auto-Response-Suppress', nil]
    ].each do |key, value|
      should "ignore emails with #{key} set to #{value}" do
        assert_answer_still_in_fact_check_state(key => value)
      end
    end

    [
      ['Auto-Submitted', 'no'],
      ['Precedence', 'foo'],
      ['Subject', 'On holiday'],
      ['X-Precedence', 'bar'],
      ['X-Autoreply', 'no'],
    ].each do |key, value|
      should "progress emails when the #{key} header isn't an auto-reply value" do
        assert_answer_progresses_to_fact_check_received(key => value)
      end
    end

    should "Return Mail::Field class if the header is present" do
      answer = FactoryGirl.create(:answer_edition, :state => 'fact_check')
      message = fact_check_mail_for(answer)
      assert_equal message['From'].class, Mail::Field
    end

    should "Return NilClass class if the header is not present" do
      answer = FactoryGirl.create(:answer_edition, :state => 'fact_check')
      message = fact_check_mail_for(answer)
      assert_equal message['X-Some-Random-Header'].class, NilClass
    end
  end
end
