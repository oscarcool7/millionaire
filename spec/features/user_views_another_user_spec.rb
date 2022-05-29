require 'rails_helper'

RSpec.feature 'USER views another user', type: :feature do
  let(:user) { FactoryBot.create(:user, name: 'Alex') }

  let(:game1) do
    FactoryBot.create(:game, user: user, current_level: 6, prize: 2000, created_at: '28 мая, 11:04')
  end

  let(:game2) do
    FactoryBot.create( :game, user: user, current_level: 2, prize: 0, created_at: '28 мая, 11:10')
  end

  let!(:games) { [game1, game2] }

  before do
    visit '/'
    click_link 'Alex'
  end

  feature 'unregistered user views another user' do
    scenario 'gets required url' do
      expect(page).to have_current_path '/users/1'
    end

    scenario 'gets name of user' do
      expect(page).to have_content 'Alex'
    end

    scenario 'does not change name and password' do
      expect(page).not_to have_content 'Сменить имя и пароль'
    end

    feature 'game1' do
      scenario 'gets time ot the game' do
        expect(page).to have_content '28 мая, 11:04'
      end

      scenario 'gets number of question' do
        expect(page).to have_content(game1.current_level)
      end

      scenario 'gets prize' do
        expect(page).to have_content '2 000 ₽'
      end
    end

    feature 'game2' do
      scenario 'gets time ot the game' do
        expect(page).to have_content '28 мая, 11:10'
      end

      scenario 'gets number of question' do
        expect(page).to have_content(game2.current_level)
      end

      scenario 'gets prize' do
        expect(page).to have_content '0 ₽'
      end
    end
  end
end
