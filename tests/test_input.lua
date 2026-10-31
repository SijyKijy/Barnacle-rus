local input = dofile((arg and arg[1]) or "mod/barnacle_ru/input.lua")
assert(input.normalize("  ПРИВЕТ, ЛИЯ!  ") == "привет лия")
assert(input.normalize("ТЫ ВСЁ ЕЩЁ ЗДЕСЬ?") == "ты все еще здесь")
assert(input.normalize("Hello, THERE!") == "hello there")
assert(input.normalize("What\226\128\153s your name?") == "what s your name")
assert(input.normalize("...") == "" and input.normalize("…") == "")
assert(input.contains_word("да конечно", "да"))
assert(not input.contains_word("иногда", "да"))
assert(not input.contains_word("нетерпение", "нет"))
assert(input.is_name_refusal(input.normalize("НЕТ!")))
assert(input.is_name_refusal(input.normalize("НЕ ХОЧУ")))
assert(not input.is_name_refusal(input.normalize("Нетерпение")))
assert(input.truncate("Александр Александрович🙂", 22) == "Александр Александрови")
assert(input.length(input.truncate("Александр Александрович🙂", 23)) == 23)
assert(input.truncate("🙂🙂🙂", 2) == "🙂🙂")
assert(input.truncate("English name", 7) == "English")

local triggers = {
	{key = "hello", patterns = {"hello", "hi"}},
	{key = "no_alone", patterns = {"no"}},
	{key = "what_alone", patterns = {"what"}},
	{key = "where_alone", patterns = {"where"}},
	{key = "whats_your_name", patterns = {"what is your name", "what's your name"}},
	{key = "name_ask_player", patterns = {"what is my name"}},
	{key = "time_now", patterns = {"what time is it"}},
	{key = "are_you_there", patterns = {"are you there"}},
	{key = "want_to_stay", patterns = {"i want to stay"}},
	{key = "where_am_i_spawn", patterns = {"where am i"}},
	{key = "what_happened_to_you", patterns = {"what happened to you"}},
	{key = "what_happened", patterns = {"what happened"}},
	{key = "ellipsis", patterns = {"...", "…"}},
	{key = "question_marks", patterns = {"??", "???"}},
}
input.extend_triggers(triggers)
local function intent(message)
	local matched = input.match_trigger(triggers, input.normalize(message))
	return matched and matched.key
end
assert(intent("ПРИВЕТ!") == "hello")
assert(intent("Как тебя зовут?") == "whats_your_name")
assert(intent("Как меня зовут?") == "name_ask_player")
assert(intent("Который сейчас час?") == "time_now")
assert(intent("ГДЕ Я?") == "where_am_i_spawn")
assert(intent("Что с тобой случилось?") == "what_happened_to_you")
assert(intent("Ты всё ещё здесь?") == "are_you_there")
assert(intent("Я НЕ ХОЧУ ОСТАТЬСЯ") ~= "want_to_stay")
assert(intent("Нетерпение") ~= "no_alone")
assert(intent("hello") == "hello")
assert(intent("what's your name?") == "whats_your_name")
assert(intent("what happened to you") == "what_happened_to_you")
for _, message in ipairs({"...", "…", "??", "???"}) do
	assert(intent(message) == nil, "Punctuation must preserve the original fallback behavior")
end
assert(input.followup_topic(input.normalize("Я заблудился")) == "lost")
assert(input.followup_topic(input.normalize("Мне СТРАШНО")) == "scared")
assert(input.followup_topic(input.normalize("Ничего, всё нормально")) == "quiet")
assert(input.followup_topic("i am scared") == "scared")
return true
