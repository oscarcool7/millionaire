# (c) goodprogrammer.ru

require 'rails_helper'
require 'support/my_spec_helper' # наш собственный класс с вспомогательными методами

# Тестовый сценарий для игрового контроллера
# Самые важные здесь тесты:
#   1. на авторизацию (чтобы к чужим юзерам не утекли не их данные)
#   2. на четкое выполнение самых важных сценариев (требований) приложения
#   3. на передачу граничных/неправильных данных в попытке сломать контроллер
#
RSpec.describe GamesController, type: :controller do
  # обычный пользователь
  let(:user) { FactoryBot.create(:user) }
  # админ
  let(:admin) { FactoryBot.create(:user, is_admin: true) }
  # игра с прописанными игровыми вопросами
  let(:game_w_questions) { FactoryBot.create(:game_with_questions, user: user) }

  # группа тестов на экшены контроллера, доступных залогиненным юзерам
  context 'Usual user' do
    # перед каждым тестом в группе
    before(:each) { sign_in user } # логиним юзера user с помощью спец. Devise метода sign_in

    # юзер может создать новую игру
    it 'creates game' do
      # сперва накидаем вопросов, из чего собирать новую игру
      generate_questions(15)

      post :create
      game = assigns(:game) # вытаскиваем из контроллера поле @game

      # проверяем состояние этой игры
      expect(game.finished?).to be_falsey
      expect(game.user).to eq(user)
      # и редирект на страницу этой игры
      expect(response).to redirect_to(game_path(game))
      expect(flash[:notice]).to be
    end

    # юзер отвечает на игру корректно - игра продолжается
    it 'answers correct' do
      # передаем параметр params[:letter]
      put :answer, id: game_w_questions.id, letter: game_w_questions.current_game_question.correct_answer_key
      game = assigns(:game)

      expect(game.finished?).to be_falsey
      expect(game.current_level).to be > 0
      expect(response).to redirect_to(game_path(game))
      expect(flash.empty?).to be_truthy # удачный ответ не заполняет flash
    end

    it 'answer incorrect' do
      put :answer, id: game_w_questions.id
      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(response).to redirect_to(user_path(user))
      expect(flash[:alert]).to be
    end

    # юзер берет деньги
    it 'takes money' do
      # вручную поднимем уровень вопроса до выигрыша 200
      game_w_questions.update_attribute(:current_level, 2)

      put :take_money, id: game_w_questions.id
      game = assigns(:game)

      expect(game.finished?).to be_truthy
      expect(game.prize).to eq(200)

      # пользователь изменился в базе, надо в коде перезагрузить!
      user.reload

      expect(user.balance).to eq(200)
      expect(response).to redirect_to(user_path(user))
      expect(flash[:warning]).to be
    end

    # юзер пытается создать новую игру, не закончив старую
    it 'try to create second game' do
      # убедились что есть игра в работе
      expect(game_w_questions.finished?).to be_falsey
      # отправляем запрос на создание, убеждаемся что новых Game не создалось
      expect { post :create }.to change(Game, :count).by(0)

      game = assigns(:game) # вытаскиваем из контроллера поле @game

      expect(game).to be_nil
      # и редирект на страницу старой игры
      expect(response).to redirect_to(game_path(game_w_questions))
      expect(flash[:alert]).to be
    end
  end

  describe '#help' do
    context 'when registered user' do
      before(:each) { sign_in user }

      context 'and ask 50/50' do
        it 'no hint in the help_hash of current question' do
          expect(game_w_questions.current_game_question.help_hash[:fifty_fifty]).not_to be
        end

        it 'the hint was not used' do
          expect(game_w_questions.fifty_fifty_used).to be false
        end

        context 'when added hint' do
          before(:each) { put :help, id: game_w_questions.id, help_type: :fifty_fifty }
          let(:game) { assigns(:game) }

          it 'game not finished' do
            expect(game.finished?).to be false
          end

          it 'the hint was used' do
            expect(game.fifty_fifty_used).to be true
          end

          it 'the hint is in the help_hash of current question' do
            expect(game.current_game_question.help_hash[:fifty_fifty]).to be
          end

          it 'the hint contains the correct answer' do
            expect(game.current_game_question.help_hash[:fifty_fifty]).to include('d')
          end

          it 'the hint contains 2 possible answers' do
            expect(game.current_game_question.help_hash[:fifty_fifty].size).to eq 2
          end

          it 'redirect to the current game page' do
            expect(response).to redirect_to(game_path(game))
          end
        end
      end

      context 'and ask audience help' do
        it 'no hint in the help_hash of current question' do
          expect(game_w_questions.current_game_question.help_hash[:audience_help]).not_to be
        end

        it 'the hint was not used' do
          expect(game_w_questions.audience_help_used).to be false
        end

        context 'when added hint' do
          before(:each) { put :help, id: game_w_questions.id, help_type: :audience_help }
          let(:game) { assigns(:game) }

          it 'game not finished' do
            expect(game.finished?).to be false
          end

          it 'the hint was used' do
            expect(game.audience_help_used).to be true
          end

          it 'the hint is in the help_hash of current question' do
            expect(game.current_game_question.help_hash[:audience_help]).to be
          end

          it 'the hint contains answer options' do
            expect(game.current_game_question.help_hash[:audience_help].keys).to contain_exactly('a', 'b', 'c', 'd')
          end

          it 'redirect to the current game page' do
            expect(response).to redirect_to(game_path(game))
          end
        end
      end
    end
  end

  describe '#show' do
    # группа тестов для незалогиненного юзера (Анонимус)
    context 'when anonymous user' do
      before(:each) { get :show, id: game_w_questions.id }
      # вызываем экшен
      context "kick" do
        it 'the status is not 200' do
          expect(response.status).not_to eq(200) # статус не 200 ОК
        end

        it 'redirect to the log in' do
          expect(response).to redirect_to(new_user_session_path) # devise должен отправить на логин
        end

        it 'flash has an alert' do
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end

    # группа тестов, доступных залогиненным юзерам
    context 'when registered user' do
      before(:each) { sign_in user }

      context 'sees the own game' do
        before(:each) { get :show, id: game_w_questions.id }
        let(:game) { assigns(:game) }

        it 'the game not finished' do
          expect(game.finished?).to be false
        end

        it 'user is correct' do
          expect(game.user).to eq(user)
        end

        it 'the status is 200' do
          expect(response.status).to eq(200)
        end

        it 'render show' do
          expect(response).to render_template('show')
        end
      end

      # проверка, что пользователя посылают из чужой игры
      context 'alien game' do
        # создаем новую игру, юзер не прописан, будет создан фабрикой новый
        let(:alien_game) { FactoryBot.create(:game_with_questions) }
        # пробуем зайти на эту игру текущий залогиненным user
        before(:each) { get :show, id: alien_game.id }

        it 'the status is not 200' do
          expect(response.status).not_to eq(200) # статус не 200 ОК
        end

        it 'redirect to root path' do
          expect(response).to redirect_to(root_path)
        end

        it 'flash has an alert' do
          expect(flash[:alert]).to be # во flash должен быть прописана ошибка
        end
      end
    end
  end
end
