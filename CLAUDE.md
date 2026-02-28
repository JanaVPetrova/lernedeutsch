# German learning bot - Code generation instructions
Create a Telegram bot that helps users to learn German words

### Core features
- Identify and register users via their unique Telegram ID
- Allow users to upload the list of words they want to learn in a batch with their translations from German to their language of choice and vice versa
- The users are able to learn the words in 2 modes: when they are given a word in German and expected to provide a correct translation to their language of choice; and vice versa: when they are given a word in their language of choice and are expected to provide the correct German translation
- The words should be suggested based on the Spaced Repetition algorithm
- The correctness of the user answer should be judged on a scale of 0-100% correct, where no answer is 0%, an answer with a typo or a wrong article is between 0 and 100, based on the number of mistakes; and when there is no typos and the article is correct, it's a 100% correct answer.
- The user has to be able to set up a schedule for a reminder for learning.
- The user has to be able to choose the mode of learning from the start menu of the bot.

### Technologies & Libraries
- Programming language: Ruby
- Telegram integration: gem 'telegem'
- Database: PostgreSQL
- Testing: RSpec
