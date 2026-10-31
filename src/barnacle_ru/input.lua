-- Bilingual input only; display language is handled separately.
local M = {}

local lower_cyrillic = {}
local uppercase = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
local lowercase = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local letters = {}
for char in lowercase:gmatch("[\194-\244][\128-\191]*") do
	letters[#letters + 1] = char
end
local index = 0
for char in uppercase:gmatch("[\194-\244][\128-\191]*") do
	index = index + 1
	lower_cyrillic[char] = letters[index]
end

function M.length(text)
	local _, count = (text or ""):gsub("[^\128-\191]", "")
	return count
end

function M.truncate(text, limit)
	local count, finish = 0, 0
	for position, char in text:gmatch("()([%z\1-\127\194-\244][\128-\191]*)") do
		if count >= limit then break end
		count = count + 1
		finish = position + #char - 1
	end
	return text:sub(1, finish)
end

function M.normalize(text)
	local lowered = (text or ""):gsub("[A-Z]", string.lower):gsub("[\194-\244][\128-\191]*", function(char)
		return lower_cyrillic[char] or char
	end):gsub("ё", "е")
	local stripped = lowered:gsub("^%s+", ""):gsub("%s+$", "")
	if stripped == "..." or stripped == "…" then return "..." end
	if stripped == "??" or stripped == "???" then return "??" end
	-- ASCII character classes must not consume individual UTF-8 bytes.
	lowered = lowered:gsub("[%z\1-\127]", function(char)
		return char:match("[a-z0-9]") and char or " "
	end):gsub("[\194-\244][\128-\191]*", function(char)
		if char == "\226\128\148" or char == "\226\128\147" or char == "…" or char == "\194\171" or char == "\194\187"
			or char == "\226\128\156" or char == "\226\128\157" or char == "\226\128\152" or char == "\226\128\153" or char == " " then
			return " "
		end
		return char
	end)
	local normalized = lowered:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
	return normalized
end

function M.contains_word(message, word)
	if word == "" then return false end
	local pattern = word:gsub("([^%w\128-\255])", "%%%1")
	return message:find("%f[%w\128-\255]" .. pattern .. "%f[^%w\128-\255]") ~= nil
		or message == word
end

M.aliases = {
	time_now = {"который час", "сколько времени", "сколько сейчас времени", "сколько сейчас", "который сейчас час"},
	where_am_i_spawn = {"где я", "куда я попал", "куда я попала"},
	barnacle_named = {"барнакл", "барнакль", "барнакел"},
	ok_k = {"ладно", "хорошо", "понятно", "ясно", "согласен", "договорились"},
	ok_short = {"ок", "окей", "окок", "окк"},
	yes_no = {"да", "ага", "угу", "нетушки"},
	no_alone = {"нет", "неа", "не а"},
	idk = {"не знаю", "хз", "без понятия", "понятия не имею", "я не знаю"},
	lol = {"лол", "ахах", "хаха", "смешно", "ржу", "кек"},
	question_marks = {"чего"},
	yolo = {"живем один раз", "жизнь одна"},
	im_back = {"я вернулся", "я вернулась", "я снова здесь", "снова я"},
	sleep = {"спать", "сон", "устал", "устала", "усталость", "спокойной ночи", "не могу уснуть", "не спится", "пора спать"},
	how_are_you_player = {"как дела", "как ты", "как поживаешь", "как самочувствие", "как себя чувствуешь"},
	what_are_you_doing = {"что делаешь", "чем занимаешься", "что ты делаешь", "чем ты занимаешься"},
	where_from = {"откуда ты", "где ты живешь", "из какой ты страны", "ты из германии", "ты немка"},
	who_is_it = {"кто это", "что это за существо", "что это такое", "кто за мной следит", "что за мной идет", "что за мной следует", "кто меня преследует"},
	is_someone_there = {"здесь кто нибудь есть", "тут кто нибудь есть", "тут что то есть", "я что то чувствую", "чувствую присутствие", "за мной что то идет", "за мной кто то следит", "кто то здесь"},
	what_happened = {"что произошло", "что случилось", "что здесь случилось", "что здесь произошло", "что стало с этим местом", "почему все сломано", "почему здесь все такое", "что это"},
	what_happened_to_you = {"что с тобой случилось", "что с тобой произошло", "почему ты здесь", "как ты застряла", "ты в ловушке", "почему ты не можешь уйти", "почему ты все еще здесь", "что с тобой"},
	are_you_okay = {"ты в порядке", "с тобой все хорошо", "с тобой все нормально", "ты ранена", "тебе больно", "ты в безопасности"},
	liberation = {"я убью тебя", "можно тебя убить", "позволь освободить тебя", "я хочу тебя освободить", "я могу тебя освободить", "как тебя освободить", "я положу этому конец", "я хочу помочь тебе умереть", "освободить тебя", "позволь тебе помочь"},
	found_note = {"я нашел записку", "я нашла записку", "нашел кое что", "нашла кое что", "прочитал записку", "прочитала записку", "здесь записка", "нашел табличку", "нашла табличку", "видел надпись", "вижу надпись", "прочитал что то"},
	tips = {"есть советы", "дай совет", "дай подсказку", "есть подсказки", "подскажи", "как выжить", "как остаться в безопасности", "что мне нужно знать", "подсказка", "совет"},
	exploring = {"гуляю", "брожу", "осматриваюсь", "исследую", "исследовать", "я гуляю", "осматриваю", "строю", "строительство", "я что то построил", "я строю"},
	want_to_stay = {"я хочу остаться", "я останусь", "я остаюсь", "я не уйду", "я не собираюсь уходить", "я никуда не уйду", "я хочу быть здесь", "не буду уходить"},
	why = {"почему", "зачем", "но почему", "почему так", "с чего бы"},
	because = {"потому что", "потому"},
	who_are_you = {"кто ты", "ты кто", "с кем я говорю", "кто мне пишет"},
	whats_your_name = {"как тебя зовут", "как твое имя", "какое у тебя имя", "как мне тебя называть"},
	my_name_callme = {"меня зовут", "мое имя", "зови меня", "называй меня"},
	where_are_we = {"где мы", "где это", "что это за место", "что за место"},
	who_am_i = {"кто я", "что я такое"},
	what_are_you = {"что ты такое", "ты настоящая", "ты реальная", "ты человек", "ты живая", "ты нпс", "ты искусственный интеллект", "ты ии", "ты бот"},
	are_you_alone = {"ты одна", "я один", "я одна", "тут кто есть", "есть кто здесь", "есть кто нибудь"},
	where_are_you = {"где ты", "где лия", "ты где", "где находишься"},
	save_me = {"я тебя найду", "как тебя найти", "можно тебя найти", "как тебя спасти", "я могу тебя спасти", "я хочу тебе помочь", "я тебе помогу", "помогу тебе"},
	help = {"помоги мне", "пожалуйста помоги", "нужна помощь", "мне нужна помощь", "можешь помочь", "что мне делать", "что делать", "куда идти", "что теперь", "что дальше", "помоги пожалуйста"},
	help_short = {"помоги", "помощь", "хелп"},
	can_you_help_me = {"ты можешь мне помочь", "ты мне поможешь", "поможешь мне", "не могла бы ты мне помочь", "сможешь помочь мне"},
	can_i_help_you = {"тебе помочь", "тебе нужна помощь", "я могу тебе помочь", "что тебе нужно", "чем я могу помочь", "чем тебе помочь", "как я могу помочь"},
	are_you_there = {"ты здесь", "ты тут", "слышишь меня", "ты меня слышишь", "ты еще здесь", "ты еще тут", "ты все еще здесь", "ты все еще тут"},
	what_do_you_mean = {"что ты имеешь в виду", "в смысле", "объясни", "я не понимаю", "что ты говоришь", "поясни", "о чем ты"},
	danger = {"я в опасности", "это опасно", "здесь опасно", "я в безопасности", "тут безопасно", "я умру", "я могу умереть", "можно умереть"},
	watched = {"за мной следят", "это жутко", "мне страшно", "мне не нравится", "мне не по себе", "это странно", "чувствую себя странно", "я боюсь"},
	thanks_sorry = {"спасибо", "благодарю", "прости", "извини", "мне жаль", "прошу прощения", "спс"},
	name_ask_player = {"как меня зовут", "помнишь мое имя", "знаешь мое имя", "ты помнишь мое имя"},
	where_alone = {"где", "куда"},
	what_alone = {"что"},
	hello = {"привет", "здравствуй", "здорово", "хай", "приветствую", "добрый день", "добрый вечер", "здравствуйте"},
	bye = {"пока", "до свидания", "увидимся", "до встречи", "бай", "я ухожу", "ухожу"},
}

function M.extend_triggers(triggers)
	for _, trigger in ipairs(triggers) do
		for _, pattern in ipairs(M.aliases[trigger.key] or {}) do
			trigger.patterns[#trigger.patterns + 1] = pattern
		end
	end
end

function M.match_trigger(triggers, message)
	local best, best_length = nil, 0
	for _, trigger in ipairs(triggers) do
		for _, pattern in ipairs(trigger.patterns or {}) do
			local normalized = M.normalize(pattern)
			local length = M.length(normalized)
			local hit = length > 0 and (length <= 3
				and M.contains_word(message, normalized)
				or length > 3 and message:find(normalized, 1, true) ~= nil)
			if hit and length > best_length then
				best, best_length = trigger, length
			end
		end
	end
	return best
end

function M.is_name_refusal(message)
	return message == "no" or message == "nope" or message == "nah" or message == "nein"
		or message == "нет" or message == "неа" or message == "не а" or message == "не хочу"
		or message == "не скажу" or message == "не буду" or message == "не хочу говорить"
end

function M.followup_topic(message)
	for _, word in ipairs({"lost", "where", "заблуд", "потерял", "где", "куда"}) do
		if message:find(word, 1, true) then return "lost" end
	end
	for _, word in ipairs({"scared", "afraid", "страшно", "боюсь", "испуг", "страх"}) do
		if message:find(word, 1, true) then return "scared" end
	end
	for _, word in ipairs({"quiet", "nothing", "fine", "тихо", "тишина", "ничего", "нормально", "в порядке"}) do
		if message:find(word, 1, true) then return "quiet" end
	end
end

return M
