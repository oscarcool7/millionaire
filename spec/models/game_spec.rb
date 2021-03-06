# (c) goodprogrammer.ru

# Стандартный rspec-овский помощник для rails-проекта
require 'rails_helper'

# Наш собственный класс с вспомогательными методами
require 'support/my_spec_helper'

# Тестовый сценарий для модели Игры
#
# В идеале — все методы должны быть покрыты тестами, в этом классе содержится
# ключевая логика игры и значит работы сайта.
RSpec.describe Game, type: :model do
  # Пользователь для создания игр
  let(:user) { FactoryBot.create(:user) }

  # Игра с прописанными игровыми вопросами
  let(:game_w_questions) do
    FactoryBot.create(:game_with_questions, user: user)
  end

  # Группа тестов на работу фабрики создания новых игр
  context 'Game Factory' do
    it 'Game.create_game! new correct game' do
      # Генерим 60 вопросов с 4х запасом по полю level, чтобы проверить работу
      # RANDOM при создании игры.
      generate_questions(60)

      game = nil

      # Создaли игру, обернули в блок, на который накладываем проверки
      expect {
        game = Game.create_game_for_user!(user)
        # Проверка: Game.count изменился на 1 (создали в базе 1 игру)
      }.to change(Game, :count).by(1).and(
        # GameQuestion.count +15
        change(GameQuestion, :count).by(15).and(
          # Game.count не должен измениться
          change(Question, :count).by(0)
        )
      )

      # Проверяем статус и поля
      expect(game.user).to eq(user)
      expect(game.status).to eq(:in_progress)

      # Проверяем корректность массива игровых вопросов
      expect(game.game_questions.size).to eq(15)
      expect(game.game_questions.map(&:level)).to eq (0..14).to_a
    end
  end

  # Тесты на основную игровую логику
  context 'game mechanics' do
    # Правильный ответ должен продолжать игру
    it 'answer correct continues game' do
      # Текущий уровень игры и статус
      level = game_w_questions.current_level
      q = game_w_questions.current_game_question
      expect(game_w_questions.status).to eq(:in_progress)

      game_w_questions.answer_current_question!(q.correct_answer_key)

      # Перешли на след. уровень
      expect(game_w_questions.current_level).to eq(level + 1)

      # Ранее текущий вопрос стал предыдущим
      expect(game_w_questions.current_game_question).not_to eq(q)

      # Игра продолжается
      expect(game_w_questions.status).to eq(:in_progress)
      expect(game_w_questions.finished?).to be_falsey
    end

    it 'take_money! finishes the game' do
      # берем игру и отвечаем на текущий вопрос
      q = game_w_questions.current_game_question
      game_w_questions.answer_current_question!(q.correct_answer_key)

      # взяли деньги
      game_w_questions.take_money!

      prize = game_w_questions.prize
      expect(prize).to be > 0

      # проверяем что закончилась игра и пришли деньги игроку
      expect(game_w_questions.status).to eq :money
      expect(game_w_questions.finished?).to be_truthy
      expect(user.balance).to eq prize
    end
  end

  context '.status' do
    # перед каждым тестом "завершаем игру"
    before(:each) do
      game_w_questions.finished_at = Time.now
      expect(game_w_questions.finished?).to be_truthy
    end

    it ':won' do
      game_w_questions.current_level = Question::QUESTION_LEVELS.max + 1
      expect(game_w_questions.status).to eq(:won)
    end

    it ':fail' do
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:fail)
    end

    it ':timeout' do
      game_w_questions.created_at = 1.hour.ago
      game_w_questions.is_failed = true
      expect(game_w_questions.status).to eq(:timeout)
    end

    it ':money' do
      expect(game_w_questions.status).to eq(:money)
    end
  end

  describe '.current_game_question' do
    it 'return current game question' do
      expect(game_w_questions.current_game_question).to eq(game_w_questions.game_questions[0])
    end
  end

  describe '.previous_level' do
    let(:level) { game_w_questions.current_level }

    it 'return correct level' do
      expect(game_w_questions.previous_level).to eq(level - 1)
    end
  end

  describe '#answer_current_question!' do
    let(:question) { game_w_questions.current_game_question }

    context 'when answer correct' do
      before { game_w_questions.answer_current_question!(question.correct_answer_key) }

      it 'return true value' do
        expect(game_w_questions.answer_current_question!(question.correct_answer_key)).to be true
      end

      it 'status of the game - in progress' do
        expect(game_w_questions.status).to eq :in_progress
      end

      it 'game not finished' do
        expect(game_w_questions.finished?).to be false
      end
    end

    context 'when answer incorrect' do
      let(:wrong_answer) { 'c' }
      before { game_w_questions.answer_current_question!(wrong_answer) }

      it 'return false value' do
        expect(game_w_questions.answer_current_question!(wrong_answer)).to be false
      end

      it 'status of the game - fail' do
        expect(game_w_questions.status).to eq :fail
      end

      it 'game finished' do
        expect(game_w_questions.finished?).to be true
      end
    end

    context 'when last question' do
      before do
        game_w_questions.current_level = Question::QUESTION_LEVELS.max
        game_w_questions.answer_current_question!(question.correct_answer_key)
      end

      it 'gets max level' do
        expect(game_w_questions.current_level).to eq Question::QUESTION_LEVELS.max + 1
      end

      it 'gets prize - 1000000' do
        expect(game_w_questions.prize).to eq 1000000
      end

      it 'status of the game - won' do
        expect(game_w_questions.status).to eq :won
      end

      it 'game finished' do
        expect(game_w_questions.finished?).to be true
      end
    end

    context 'when time is over' do
      before do
        game_w_questions.created_at = 1.hour.ago
        game_w_questions.answer_current_question!(question.correct_answer_key)
      end

      it 'return false value' do
        expect(game_w_questions.answer_current_question!(question.correct_answer_key)).to be false
      end

      it 'status of the game - timeout' do
        expect(game_w_questions.status).to eq :timeout
      end

      it 'game finished' do
        expect(game_w_questions.finished?).to be true
      end
    end
  end
end
