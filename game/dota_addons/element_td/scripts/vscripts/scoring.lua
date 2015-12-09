-- scoring.lua
-- manages custom games scoring such as wave clearing, bonus and total score
if not Scoring then
	Scoring = {}
	Scoring.__index = Scoring

	SCORING_OBJECTS = {}
end

ScoringObject = createClass({
		constructor = function( self, playerID )
			self.playerID = playerID
			self.totalScore = 0
			self.cleanWaves = 0
			self.under30 = 0
		end
	},
{}, nil)

SCORING_WAVE_CLEAR = 0
SCORING_WAVE_LOST = 1
SCORING_GAME_CLEAR = 2
function ScoringObject:UpdateScore( const )
	local scoreTable = {}
	local processed = {}
	local playerData = GetPlayerData(self.playerID)

	if ( const == SCORING_WAVE_CLEAR ) then
		scoreTable = self:GetWaveCleared()
		table.insert(processed, 'Wave ' .. playerData.completedWaves .. ' cleared!' )
	elseif ( const == SCORING_WAVE_LOST ) then
		scoreTable = self:GetWaveLost()
		table.insert(processed, 'Game over! Lost on wave ' .. playerData.completedWaves + 1 )
	elseif ( const == SCORING_GAME_CLEAR ) then
		scoreTable = self:GetGameCleared()
		table.insert(processed, 'Game cleared! Your score ' .. self.totalScore )
	else
		return false
	end

	-- Process Score Table keeping ordering below
	if scoreTable['clearBonus'] then
		table.insert(processed, 'Wave ' .. playerData.completedWaves .. ' clear bonus: ' .. scoreTable['clearBonus'] )
	end
	if scoreTable['cleanBonus'] then
		if scoreTable['cleanBonus'] ~= 0 then
			table.insert(processed, 'Clean bonus: ' .. GetPctString(scoreTable['cleanBonus']) )
		else
			local livesDiff = playerData.waveObject.healthWave - playerData.health 
			table.insert(processed, livesDiff .. ' Lives lost' )
		end
	end
	if scoreTable['speedBonus'] then
		table.insert(processed, 'Speed bonus: ' .. GetPctString(scoreTable['speedBonus']) )
	end
	if scoreTable['cleanWaves'] then
		table.insert(processed, 'Clean waves: ' .. scoreTable['cleanWaves'] )
	end
	if scoreTable['under30'] then
		table.insert(processed, 'Under 30 waves: ' .. scoreTable['under30'] )
	end
	if scoreTable['networthBonus'] then
		table.insert(processed, 'Networth bonus: '.. scoreTable['networthBonus'] )
	end
	if scoreTable['bossBonus'] then
		table.insert(processed, 'Boss bonus: '.. GetPctString(scoreTable['bossBonus']) )
	end
	if scoreTable['difficultyBonus'] then
		table.insert(processed, GetPlayerDifficulty( self.playerID ) .. ' difficulty: '.. GetPctString(scoreTable['difficultyBonus']) )
	end
	if scoreTable['totalScore'] then
		table.insert(processed, 'Total score: ' .. scoreTable['totalScore'] )
		self.totalScore = self.totalScore + scoreTable['totalScore']		
	end
	PrintTable(processed)
	return true
end

function GetPctString( number )
	local percent = round(number * 100)
	local processed = percent
	if percent >= 0 then
		processed = '+' .. percent
	end
	return processed .. '%'
end

-- Returns WaveClearBonus, CleanBonus/Lives lost/SpeedBonus/TotalScore for the round.
function ScoringObject:GetWaveCleared()
	local playerData = GetPlayerData( self.playerID )
	local waveClearScore = self:GetWaveClearBonus( playerData.completedWaves )
	local cleanBonus = self:GetCleanBonus( playerData.waveObject.healthWave <= playerData.health )
	local time = playerData.waveObject.endTime - playerData.waveObject.startTime
	local speedBonus = self:GetSpeedBonus( time )
	local totalScore = math.ceil(waveClearScore * (cleanBonus + speedBonus + 1))

	print("Time: "..time)
	return { clearBonus = waveClearScore, cleanBonus = cleanBonus, speedBonus = speedBonus, totalScore = totalScore }
end

-- Returns amount of clean waves and waves under 30 as well as total score
function ScoringObject:GetWaveLost()
	local score = self.totalScore
	local clean = self.cleanWaves
	local under30 = self.under30

	return { cleanWaves = clean, under30 = under30, totalScore = score }
end

-- Total Score, BossBonus, DifficultyBonus, TotalScore after bonus
function ScoringObject:GetGameCleared()
	local score = self.totalScore
	local totalScore = 0
	local networthBonus = 1
	local difficultyBonus = 1
	local bossBonus = 1

	if EXPRESS_MODE then
		networthBonus = self:GetNetworthBonus()
	else
		bossBonus = self:GetBossBonus()
	end
	difficultyBonus = self:GetDifficultyBonus()

	totalScore = math.ceil(score * (networthBonus + difficultyBonus + bossBonus + 1))

	return { networthBonus = networthBonus, difficultyBonus = difficultyBonus, bossBonus = bossBonus, totalScore = totalScore }
end

-- takes leaks (lives) per wave (1.20 multiplier)
function ScoringObject:GetCleanBonus( bool )
	local bonus = 0
	if bool then
		self.cleanWaves = self.cleanWaves + 1
		bonus = 0.2
	end
	return bonus
end

-- takes time in seconds (30s multiplier 1, each second < 30 multiplier +0.02, above 30> -0.01)
function ScoringObject:GetSpeedBonus( time )
	local bonus = 1
	if time > 30 then
		bonus = bonus - ( time - 30 )*0.01 
	elseif time < 30 then
		self.under30 = self.under30 + 1
		bonus = bonus + ( 30 - time )*0.02
	end
	return bonus - 1
end

-- takes wave (Score = wave * CreepCount)
function ScoringObject:GetWaveClearBonus( wave )
	local bonus = wave * CREEPS_PER_WAVE
	return bonus
end

-- Express Only: (Player Networth/Base Networth/2)
-- Base Networth: 	Normal=88170
--					Hard=96060
--					VeryHard=110790
--					Insane=127770
function ScoringObject:GetNetworthBonus()
	local playerData = GetPlayerData( self.playerID )
	local difficulty = GetPlayerDifficulty( self.playerID )
	local playerNetworth = 0
	local baseWorth = 88170
	for i,v in pairs( playerData.towers ) do
		local tower = EntIndexToHScript( i )
		if tower:GetHealth() == tower:GetMaxHealth() then
			for i=0,16 do
				local ability = tower:GetAbilityByIndex( 0 )
				if ability then
					local name = ability:GetAbilityName()
					if ( name == "sell_tower_100" ) then
						playerNetworth = playerNetworth + GetUnitKeyValue( tower.class, "TotalCost" )
					elseif ( name == "sell_tower_75" ) then
						playerNetworth = playerNetworth + round( GetUnitKeyValue( tower.class, "TotalCost" ) * 0.75 )
					end
				end
			end
		end
	end
	if ( difficulty == "Hard" ) then
		baseWorth = 96060
	elseif ( difficulty == "VeryHard" ) then
		baseWorth = 110790
	elseif ( difficulty == "Insane" ) then
		baseWorth = 127770
	end
	return (playerNetworth/baseWorth/2)
end

-- Classic Only: 1.05 + 0.01 per additional wave
function ScoringObject:GetBossBonus( waves )
	local bonus = 0.05
	if waves > 0 then
		bonus = bonus + waves*0.01
	end
	return bonus
end

-- Normal (1x), Hard (1.5x), Very Hard (2x), Insane (2.5x)
function ScoringObject:GetDifficultyBonus()
	local bonus = 0 -- Normal
	local difficulty = GetPlayerDifficulty( self.playerID )
	if ( difficulty == "Hard" ) then
		bonus = 0.5
	elseif ( difficulty == "VeryHard" ) then
		bonus = 1
	elseif ( difficulty == "Insane" ) then
		bonus = 1.5
	end
	return bonus
end

----------------------------------------------------
