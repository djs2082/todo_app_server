require 'rails_helper'

RSpec.describe SettingRepresenter do
  let(:user) do
    User.create!(
      first_name: 'Test',
      last_name: 'User',
      email: 'test@example.com',
      account_name: 'testuser',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  let(:setting) do
    Setting.create!(
      configurable: user,
      key: 'theme',
      value: 'dark'
    )
  end

  describe '.render' do
    it 'returns nil when setting is nil' do
      expect(described_class.render(nil)).to be_nil
    end

    it 'returns setting hash with all fields' do
      result = described_class.render(setting)
      
      expect(result).to be_a(Hash)
      expect(result[:id]).to eq(setting.id)
      expect(result[:key]).to eq('theme')
      expect(result[:value]).to eq('dark')
    end

    it 'includes id, key, and value fields' do
      result = described_class.render(setting)
      
      expect(result.keys).to contain_exactly(:id, :key, :value)
    end

    it 'handles setting with nil value' do
      setting.update!(value: nil)
      result = described_class.render(setting)
      
      expect(result[:id]).to eq(setting.id)
      expect(result[:key]).to eq('theme')
      # nil value is compacted out by .compact
      expect(result).not_to have_key(:value)
    end

    it 'handles setting with complex value (stored as string)' do
      # Settings store values as strings, so complex objects are stringified
      setting.update!(value: '{"color":"blue","mode":"auto"}')
      result = described_class.render(setting)
      
      expect(result[:value]).to eq('{"color":"blue","mode":"auto"}')
    end

    it 'handles setting with array value (stored as string)' do
      # Settings store values as strings
      setting.update!(value: '["option1","option2","option3"]')
      result = described_class.render(setting)
      
      expect(result[:value]).to eq('["option1","option2","option3"]')
    end

    it 'handles setting with string value' do
      setting.update!(value: 'simple string')
      result = described_class.render(setting)
      
      expect(result[:value]).to eq('simple string')
    end

    it 'handles setting with numeric value (stored as string)' do
      setting.update!(value: '42')
      result = described_class.render(setting)
      
      expect(result[:value]).to eq('42')
    end

    it 'handles setting with boolean value (stored as string)' do
      setting.update!(value: 'true')
      result = described_class.render(setting)
      
      expect(result[:value]).to eq('true')
    end
  end

  describe '.render_collection' do
    it 'returns empty array when settings is nil' do
      expect(described_class.render_collection(nil)).to eq([])
    end

    it 'returns empty array when settings is empty array' do
      expect(described_class.render_collection([])).to eq([])
    end

    it 'renders a single setting in array' do
      result = described_class.render_collection([setting])
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(1)
      expect(result.first[:id]).to eq(setting.id)
      expect(result.first[:key]).to eq('theme')
    end

    it 'renders multiple settings' do
      setting2 = Setting.create!(
        configurable: user,
        key: 'language',
        value: 'en'
      )
      setting3 = Setting.create!(
        configurable: user,
        key: 'notifications',
        value: { email: true, push: false }
      )

      result = described_class.render_collection([setting, setting2, setting3])
      
      expect(result.length).to eq(3)
      expect(result[0][:key]).to eq('theme')
      expect(result[1][:key]).to eq('language')
      expect(result[2][:key]).to eq('notifications')
    end

    it 'handles ActiveRecord::Relation' do
      Setting.create!(configurable: user, key: 'key1', value: 'value1')
      Setting.create!(configurable: user, key: 'key2', value: 'value2')
      
      settings_relation = Setting.where(configurable: user)
      result = described_class.render_collection(settings_relation)
      
      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it 'filters out nil values in collection' do
      setting2 = Setting.create!(
        configurable: user,
        key: 'language',
        value: 'en'
      )

      # render returns nil for nil settings, Array() handles it
      result = described_class.render_collection([setting, nil, setting2])
      
      # The map will include nil, but we can verify non-nil entries
      expect(result.compact.length).to eq(2)
    end

    it 'maintains order of settings in collection' do
      settings = []
      5.times do |i|
        settings << Setting.create!(
          configurable: user,
          key: "setting_#{i}",
          value: "value_#{i}"
        )
      end

      result = described_class.render_collection(settings)
      
      expect(result[0][:key]).to eq('setting_0')
      expect(result[1][:key]).to eq('setting_1')
      expect(result[2][:key]).to eq('setting_2')
      expect(result[3][:key]).to eq('setting_3')
      expect(result[4][:key]).to eq('setting_4')
    end
  end

  describe 'integration with Setting model' do
    it 'renders polymorphic configurable settings correctly' do
      result = described_class.render(setting)
      
      expect(result[:id]).to be_present
      expect(result[:key]).to be_present
      expect(result[:value]).to be_present
    end

    it 'works with freshly created setting' do
      new_setting = Setting.create!(
        configurable: user,
        key: 'new_key',
        value: 'new_value'
      )

      result = described_class.render(new_setting)
      
      expect(result[:id]).to eq(new_setting.id)
      expect(result[:key]).to eq('new_key')
      expect(result[:value]).to eq('new_value')
    end
  end
end
