; 
; Copyright 2011-2012 Jeff Bush
; 
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 

; work in progress, not really functional yet...
;
; Simple Euler integration n-body simulation
; Exercises:
;   - Accessing array of structures (AOS)
;   - floating point arithmetic
;

;
; struct Body {
;     float pX, pY, pZ;	// Position of the body
;     float vX, vY, vZ; // Velocity of the body
; };
;

							BODY_STRUCT_SIZE = 24
							NUM_STRANDS = 4

; Does one update
nbody						.enterscope
							; Params
							.regalias arrayBase s0
							.regalias arrayCount s1

							; Local variables
							.regalias pX vf0
							.regalias pY vf1
							.regalias pZ vf2
							.regalias vX vf3
							.regalias vY vf4
							.regalias vZ vf5
							.regalias dX vf6
							.regalias dY vf7
							.regalias dZ vf8
							.regalias fX vf9			; total force
							.regalias fY vf10
							.regalias fZ vf11
							.regalias sum vf12
							.regalias vTmp vf13
							.regalias vMagic vf14
							.regalias otherX f10		; Interacting particle
							.regalias otherY f2
							.regalias otherZ f3
							.regalias pBody s4		; Pointer to body struct
							.regalias tmp s5
							.regalias interactorCount s6
							.regalias dT sf7
							.regalias updateBodyCount s8
							.regalias pOther s9
							.regalias syncPtr s10
							.regalias newCount s11

							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Update velocities of particles
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							f5 = mem_l[kMagic]	; tmp
							vMagic = f5

							dT = mem_l[timeIncrement]
							updateBodyCount = arrayCount
							pBody = arrayBase
UpdateVelocityLoop			; Load elements from 16 structures into vector regs
							pX = mem_l[pBody, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pZ = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vX = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vZ = mem_l[tmp, BODY_STRUCT_SIZE]

							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Iterate through all other particles to compute 
							;; forces with this set.
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							v9 = 0	; fX
							v10 = 0	; fY
							v11 = 0 ; fZ
							interactorCount = arrayCount
InteractLoop				otherX = mem_l[pOther]
							otherY = mem_l[pOther + 4]
							otherZ = mem_l[pOther + 8]	
							
							; Compute attraction between these two particles, inverse 
							; square law
							dX = pX - otherX
							dY = pY - otherY
							dZ = pZ - otherZ
							dX = dX * dX
							dY = dY * dY
							dZ = dZ * dZ
							sum = dX + dY
							sum = sum + dZ
							
							; Approximate reciprocal square root
							; http://en.wikipedia.org/wiki/Fast_inverse_square_root
							v12 = v12 >> 1		; sum = sum >> 1
							v12 = v14 - v12		; sum = magic - sum
							
							; XXX Could do extra Newton iteration

							; Accumulate force on the target particle
							vTmp = sum * sum
							vTmp = vTmp * sum
							
							dX = dX * vTmp
							dY = dY * vTmp
							dZ = dZ * vTmp
							
							fX = fX + dX
							fY = fY + dY
							fZ = fZ + dZ
							
							pOther = pOther + BODY_STRUCT_SIZE
							interactorCount = interactorCount - 1
							if interactorCount goto InteractLoop

							; Integrate and update velocities
							fX = fX * dT
							fY = fY * dT
							fZ = fZ * dT
							vX = vX + fX
							vY = vY + fY
							vZ = vZ + fZ

							; Write back new velocity
							tmp = pBody + 12
							mem_l[tmp, BODY_STRUCT_SIZE] = vX
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = vY
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = vZ
							
							; Bottom of loop
							pBody = pBody + 16 * BODY_STRUCT_SIZE * NUM_STRANDS
							updateBodyCount = updateBodyCount - 16
							if updateBodyCount goto UpdateVelocityLoop							

							; Wait for all strands to finish processing
							syncPtr = &barrierCount
barrier0					newCount = mem_sync[syncPtr]	; get current count
							newCount = newCount + 1			; next count
							tmp = newCount - NUM_STRANDS	; all strands ready
							if !tmp goto barrier0Release	; if yes, then wake
							mem_sync[syncPtr] = tmp			; try to update count
							if !tmp goto barrier0			; if race, retry
							goto barrier0Wait				; wait for everyone else
barrier0Release				tmp = 0							; reset barrier
							mem_l[syncPtr] = tmp
							goto barrier0Done
barrier0Wait				newCount = mem_l[syncPtr]		; If everyone is not done, wait
							if newCount goto barrier0Wait
barrier0Done


							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
							;; Update positions of all bodies
							;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

							updateBodyCount = arrayCount
							pBody = arrayBase
UpdatePosLoop				; Load elements from 16 structures into vector regs
							pX = mem_l[pBody, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							pZ = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vX = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vY = mem_l[tmp, BODY_STRUCT_SIZE]
							tmp = pBody + 4
							vZ = mem_l[tmp, BODY_STRUCT_SIZE]

							vX = vX * dT
							vY = vY * dT
							vZ = vZ * dT
							pX = pX + vX
							pY = pY + vY
							pZ = pZ + vZ
							
							; Write back new positions
							mem_l[pBody, BODY_STRUCT_SIZE] = pX
							tmp = pBody + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = pY
							tmp = tmp + 4
							mem_l[tmp, BODY_STRUCT_SIZE] = pZ

							; Bottom of loop
							pBody = pBody + 16 * BODY_STRUCT_SIZE * NUM_STRANDS
							updateBodyCount = updateBodyCount - (16 * NUM_STRANDS)
							if updateBodyCount goto UpdateVelocityLoop							

							; Wait for all strands to finish processing
							syncPtr = &barrierCount
barrier1					newCount = mem_sync[syncPtr]	; get current count
							newCount = newCount + 1			; next count
							tmp = newCount - NUM_STRANDS	; all strands ready
							if !tmp goto barrier1Release	; if yes, then wake
							mem_sync[syncPtr] = tmp			; try to update count
							if !tmp goto barrier1			; if race, retry
							goto barrier0Wait				; wait for everyone else
barrier1Release				tmp = 0							; reset barrier
							mem_l[syncPtr] = tmp
							goto barrier1Done
barrier1Wait				newCount = mem_l[syncPtr]		; If everyone is not done, wait
							if newCount goto barrier1Wait
barrier1Done

							pc = link

kMagic						.word 0x5f3759df	
barrierCount				.word 0
timeIncrement				.float 0.1
							
							.exitscope


_start						s2 = 0xf
							cr30 = s2				; Start all strands		
							s2 = cr0				; Get my strand ID

							s3 = s2 * (16 * BODY_STRUCT_SIZE)	; Block size
							s0 = &bodyStructs		; Dest
							s0 = s0 + s3			; Offset
							s1 = 256
							call nbody

							;; XXX loop for some number of iterations

							cr31 = s0				; halt

;
; from random import random
; for x in range(256):
; 	print '\t.float ' + str(random()) + ',' + str(random()) + ',' + str(random()) + ',0.0,0.0,0.0';
;					
bodyStructs	.float 0.101170869213,0.112086940054,0.247912732279,0.0,0.0,0.0
	.float 0.549391386662,0.121345013647,0.319984673944,0.0,0.0,0.0
	.float 0.29619783747,0.704735829133,0.841014286989,0.0,0.0,0.0
	.float 0.43465463564,0.211537416688,0.183474809694,0.0,0.0,0.0
	.float 0.136814394582,0.508935785209,0.849681216427,0.0,0.0,0.0
	.float 0.591500575416,0.18663266151,0.969506823337,0.0,0.0,0.0
	.float 0.966128552929,0.0838228719613,0.442616836704,0.0,0.0,0.0
	.float 0.0504907118973,0.630718956188,0.56924679419,0.0,0.0,0.0
	.float 0.325394526654,0.767877651939,0.367529313293,0.0,0.0,0.0
	.float 0.739012674473,0.341161746546,0.954158638299,0.0,0.0,0.0
	.float 0.77489590938,0.928826592774,0.670289572049,0.0,0.0,0.0
	.float 0.824596942748,0.332966272487,0.90567232716,0.0,0.0,0.0
	.float 0.362581199787,0.205300878646,0.92224877582,0.0,0.0,0.0
	.float 0.798811332108,0.268312629322,0.734635716415,0.0,0.0,0.0
	.float 0.309316202483,0.395282877337,0.108753777434,0.0,0.0,0.0
	.float 0.135053349372,0.995333911147,0.968785033839,0.0,0.0,0.0
	.float 0.156011468665,0.884955655428,0.519835256759,0.0,0.0,0.0
	.float 0.0853450725815,0.25943508158,0.196678431388,0.0,0.0,0.0
	.float 0.657136352364,0.103611624953,0.382488922588,0.0,0.0,0.0
	.float 0.316660881102,0.679944418089,0.0877042804552,0.0,0.0,0.0
	.float 0.361933133154,0.233568504131,0.746011444909,0.0,0.0,0.0
	.float 0.876457972166,0.476844989182,0.708094755492,0.0,0.0,0.0
	.float 0.111826583619,0.991860099924,0.0762315909035,0.0,0.0,0.0
	.float 0.522647078422,0.741080003815,0.845185067316,0.0,0.0,0.0
	.float 0.100779975931,0.530056514573,0.524856232698,0.0,0.0,0.0
	.float 0.282490128096,0.45931129982,0.837845571593,0.0,0.0,0.0
	.float 0.552411998335,0.903844060921,0.967322257611,0.0,0.0,0.0
	.float 0.0867315693592,0.803803406485,0.115034198163,0.0,0.0,0.0
	.float 0.0192405297894,0.538045050983,0.440720158803,0.0,0.0,0.0
	.float 0.815202644158,0.754172794092,0.256792324804,0.0,0.0,0.0
	.float 0.716735602881,0.123613251973,0.864136139261,0.0,0.0,0.0
	.float 0.988656630531,0.378489166874,0.721547156831,0.0,0.0,0.0
	.float 0.164773042129,0.540814015084,0.750550963773,0.0,0.0,0.0
	.float 0.654237433132,0.944193777972,0.147870879433,0.0,0.0,0.0
	.float 0.789673836562,0.601292307996,0.298280033101,0.0,0.0,0.0
	.float 0.226483981597,0.487107880792,0.572278390526,0.0,0.0,0.0
	.float 0.060952546627,0.67762398839,0.425566055212,0.0,0.0,0.0
	.float 0.35832359742,0.255774591211,0.436236553435,0.0,0.0,0.0
	.float 0.347034744815,0.396821551033,0.143652479945,0.0,0.0,0.0
	.float 0.145686794999,0.897278001523,0.962712794924,0.0,0.0,0.0
	.float 0.235791410898,0.459771863086,0.0881042736855,0.0,0.0,0.0
	.float 0.240240198052,0.262381318675,0.837140877055,0.0,0.0,0.0
	.float 0.366678948608,0.255289084713,0.15383717343,0.0,0.0,0.0
	.float 0.13915457203,0.977686576711,0.579976995976,0.0,0.0,0.0
	.float 0.24319773677,0.936663524483,0.878895672811,0.0,0.0,0.0
	.float 0.702865079225,0.904419479904,0.36966298448,0.0,0.0,0.0
	.float 0.64330149289,0.712475310185,0.633713820231,0.0,0.0,0.0
	.float 0.766683159483,0.526610671686,0.475231459184,0.0,0.0,0.0
	.float 0.908468106117,0.525153969973,0.362535942279,0.0,0.0,0.0
	.float 0.879996763006,0.734067261302,0.864353889173,0.0,0.0,0.0
	.float 0.230813446288,0.242945214437,0.0981328834097,0.0,0.0,0.0
	.float 0.0226612120214,0.807743435023,0.728299248334,0.0,0.0,0.0
	.float 0.678445228019,0.258619519502,0.432218189718,0.0,0.0,0.0
	.float 0.644788503582,0.197478630712,0.747259894822,0.0,0.0,0.0
	.float 0.115424384536,0.408421512588,0.614196291174,0.0,0.0,0.0
	.float 0.68865355972,0.870155221121,0.544939640931,0.0,0.0,0.0
	.float 0.296394510463,0.802746293157,0.898500636936,0.0,0.0,0.0
	.float 0.414856795841,0.879973562908,0.823719607469,0.0,0.0,0.0
	.float 0.525646844618,0.423414343677,0.243176993577,0.0,0.0,0.0
	.float 0.879185971264,0.717182224376,0.434827693055,0.0,0.0,0.0
	.float 0.86742932006,0.196987088664,0.932571070401,0.0,0.0,0.0
	.float 0.49800095362,0.963123508624,0.0353443947278,0.0,0.0,0.0
	.float 0.760265490018,0.50640398779,0.617627588388,0.0,0.0,0.0
	.float 0.134306057459,0.533973039826,0.617669307,0.0,0.0,0.0
	.float 0.975845358844,0.549044512541,0.679255419043,0.0,0.0,0.0
	.float 0.296972331983,0.117988191512,0.276095217462,0.0,0.0,0.0
	.float 0.96528939558,0.581556513176,0.240534869817,0.0,0.0,0.0
	.float 0.0994467634036,0.707170561209,0.321598252856,0.0,0.0,0.0
	.float 0.992202418383,0.443280627067,0.345348120299,0.0,0.0,0.0
	.float 0.570391248007,0.474049322188,0.505210964641,0.0,0.0,0.0
	.float 0.395279956859,0.819597087199,0.303319840129,0.0,0.0,0.0
	.float 0.0603208505237,0.16776723782,0.479722414039,0.0,0.0,0.0
	.float 0.547201504521,0.00842219183486,0.989166017751,0.0,0.0,0.0
	.float 0.239733528398,0.239635084954,0.106038484695,0.0,0.0,0.0
	.float 0.249691517719,0.649425976536,0.348435615724,0.0,0.0,0.0
	.float 0.916395332869,0.371865484229,0.352020606891,0.0,0.0,0.0
	.float 0.508243305368,0.0984035102607,0.287181092343,0.0,0.0,0.0
	.float 0.937952801196,0.898097872292,0.524350129848,0.0,0.0,0.0
	.float 0.231022546048,0.0618052115774,0.845108651239,0.0,0.0,0.0
	.float 0.780037564074,0.571495126168,0.472733878522,0.0,0.0,0.0
	.float 0.597940872149,0.246470402107,0.349335762367,0.0,0.0,0.0
	.float 0.320357580826,0.164481850224,0.58913784402,0.0,0.0,0.0
	.float 0.986508594718,0.185083368037,0.257561432257,0.0,0.0,0.0
	.float 0.609830083147,0.559776232576,0.238563578482,0.0,0.0,0.0
	.float 0.60728004656,0.689736941692,0.391852480336,0.0,0.0,0.0
	.float 0.662261824326,0.358887034756,0.751460701859,0.0,0.0,0.0
	.float 0.176858546992,0.694793823007,0.219523382492,0.0,0.0,0.0
	.float 0.329966719611,0.105066631334,0.637454016605,0.0,0.0,0.0
	.float 0.885897369686,0.749214098909,0.834057322234,0.0,0.0,0.0
	.float 0.723044349514,0.204691583799,0.968020152051,0.0,0.0,0.0
	.float 0.10861240699,0.530257102433,0.327728927358,0.0,0.0,0.0
	.float 0.674528180413,0.806080977808,0.913320692684,0.0,0.0,0.0
	.float 0.775543809425,0.718764510012,0.425315176757,0.0,0.0,0.0
	.float 0.0102614385705,0.477011637475,0.0467344361195,0.0,0.0,0.0
	.float 0.816429465737,0.249276656003,0.702269992716,0.0,0.0,0.0
	.float 0.427807594872,0.787280478754,0.776937122831,0.0,0.0,0.0
	.float 0.0136480893292,0.220385576496,0.545242054458,0.0,0.0,0.0
	.float 0.996781257007,0.255171122141,0.429412410836,0.0,0.0,0.0
	.float 0.0495408602832,0.663085628948,0.239894825137,0.0,0.0,0.0
	.float 0.939081759475,0.895334214692,0.990572839841,0.0,0.0,0.0
	.float 0.046540312613,0.44416190709,0.593210613421,0.0,0.0,0.0
	.float 0.42141164674,0.186490665914,0.481090479803,0.0,0.0,0.0
	.float 0.985604251871,0.397970042211,0.861891587763,0.0,0.0,0.0
	.float 0.942777092459,0.61566131412,0.15311237803,0.0,0.0,0.0
	.float 0.182808982882,0.644116694668,0.172088444848,0.0,0.0,0.0
	.float 0.549518370435,0.0715257383478,0.66681713465,0.0,0.0,0.0
	.float 0.545401472253,0.99309032912,0.320546458382,0.0,0.0,0.0
	.float 0.437797055755,0.941805493571,0.20640684905,0.0,0.0,0.0
	.float 0.173554134246,0.0194084884282,0.831680979769,0.0,0.0,0.0
	.float 0.537512648186,0.812127844379,0.105468126249,0.0,0.0,0.0
	.float 0.756839402865,0.197085145868,0.619733928584,0.0,0.0,0.0
	.float 0.0470185880773,0.258076459792,0.619189310227,0.0,0.0,0.0
	.float 0.214060658419,0.652533887213,0.331078375645,0.0,0.0,0.0
	.float 0.854130328093,0.379893391369,0.414314091466,0.0,0.0,0.0
	.float 0.510695941273,0.34626566004,0.34792789267,0.0,0.0,0.0
	.float 0.890406237271,0.392855797442,0.747778562852,0.0,0.0,0.0
	.float 0.528218454309,0.255638065033,0.43343097303,0.0,0.0,0.0
	.float 0.495133362776,0.708958275968,0.415802294294,0.0,0.0,0.0
	.float 0.625683101157,0.0253411585972,0.49944578927,0.0,0.0,0.0
	.float 0.557736817307,0.178914319401,0.630959715071,0.0,0.0,0.0
	.float 0.915152718291,0.996313692725,0.702840756976,0.0,0.0,0.0
	.float 0.898826194624,0.0228567052859,0.490011002209,0.0,0.0,0.0
	.float 0.944180506582,0.113580880228,0.15111723729,0.0,0.0,0.0
	.float 0.557098366877,0.440456215011,0.376786676184,0.0,0.0,0.0
	.float 0.161392133337,0.287330755319,0.0911643014055,0.0,0.0,0.0
	.float 0.293936016895,0.625215703072,0.688180695041,0.0,0.0,0.0
	.float 0.562938529308,0.174217414967,0.384939997328,0.0,0.0,0.0
	.float 0.0295929889376,0.34151725329,0.945722526576,0.0,0.0,0.0
	.float 0.318145984494,0.997156509631,0.161726585042,0.0,0.0,0.0
	.float 0.279173420026,0.233896398352,0.918987624036,0.0,0.0,0.0
	.float 0.352223881492,0.677558741047,0.650859288632,0.0,0.0,0.0
	.float 0.288440840281,0.0610197646976,0.867613655908,0.0,0.0,0.0
	.float 0.180016246955,0.00889697261928,0.0769216797101,0.0,0.0,0.0
	.float 0.777525490484,0.539706728726,0.415296432468,0.0,0.0,0.0
	.float 0.632777444561,0.265061034477,0.768902099842,0.0,0.0,0.0
	.float 0.792322095351,0.94131382379,0.901801594811,0.0,0.0,0.0
	.float 0.17898548382,0.224346722594,0.272942028271,0.0,0.0,0.0
	.float 0.795549995932,0.078481985525,0.24347575839,0.0,0.0,0.0
	.float 0.0974996302751,0.391007019892,0.0442145907093,0.0,0.0,0.0
	.float 0.52056779873,0.91871350634,0.828550052017,0.0,0.0,0.0
	.float 0.639816339503,0.223017938021,0.128333376304,0.0,0.0,0.0
	.float 0.527857059214,0.0275665970177,0.823697964763,0.0,0.0,0.0
	.float 0.956025508145,0.2339043189,0.762627426203,0.0,0.0,0.0
	.float 0.45829496822,0.948814472366,0.92442044335,0.0,0.0,0.0
	.float 0.951488441444,0.747789769234,0.42403927008,0.0,0.0,0.0
	.float 0.669599925594,0.994355499393,0.693851681187,0.0,0.0,0.0
	.float 0.558974362471,0.0298236901252,0.655876794903,0.0,0.0,0.0
	.float 0.512827303827,0.877555066207,0.609030384,0.0,0.0,0.0
	.float 0.861782918828,0.928269289862,0.89909082549,0.0,0.0,0.0
	.float 0.870523692294,0.0549224837524,0.653416518625,0.0,0.0,0.0
	.float 0.236725837086,0.755068795233,0.795659834235,0.0,0.0,0.0
	.float 0.718622976565,0.585056131182,0.81074911097,0.0,0.0,0.0
	.float 0.259585578992,0.698759568442,0.373815354693,0.0,0.0,0.0
	.float 0.758732075242,0.81829823512,0.801963320779,0.0,0.0,0.0
	.float 0.331542545352,0.480840399593,0.611082594491,0.0,0.0,0.0
	.float 0.576614422039,0.806007704297,0.167418220394,0.0,0.0,0.0
	.float 0.811161876572,0.944626276003,0.471720471413,0.0,0.0,0.0
	.float 0.948982000102,0.714685752338,0.963726462214,0.0,0.0,0.0
	.float 0.0241435475244,0.151146346548,0.893785191189,0.0,0.0,0.0
	.float 0.233878179375,0.0887759597187,0.802830476641,0.0,0.0,0.0
	.float 0.11845548788,0.00584037824896,0.0533235116278,0.0,0.0,0.0
	.float 0.770644117968,0.248162307377,0.851957984894,0.0,0.0,0.0
	.float 0.842051905956,0.845389443663,0.708012925827,0.0,0.0,0.0
	.float 0.981505274653,0.823382796729,0.223787220525,0.0,0.0,0.0
	.float 0.541790367157,0.379127737346,0.107599830307,0.0,0.0,0.0
	.float 0.519942593958,0.899919852495,0.0625545657588,0.0,0.0,0.0
	.float 0.996122221746,0.186231262151,0.170347601378,0.0,0.0,0.0
	.float 0.839589540182,0.366123641289,0.250223372337,0.0,0.0,0.0
	.float 0.52395978382,0.584822300223,0.738094644386,0.0,0.0,0.0
	.float 0.770866334246,0.823839773293,0.883406584902,0.0,0.0,0.0
	.float 0.454123505911,0.637785471955,0.312313128046,0.0,0.0,0.0
	.float 0.760532592698,0.684600543182,0.0617299524508,0.0,0.0,0.0
	.float 0.459638905965,0.480903504032,0.23113981493,0.0,0.0,0.0
	.float 0.0965089240488,0.0584149611322,0.626330663824,0.0,0.0,0.0
	.float 0.693171574365,0.186109498806,0.0417107441788,0.0,0.0,0.0
	.float 0.702018248301,0.911034723059,0.997684211878,0.0,0.0,0.0
	.float 0.0305067398064,0.625981429288,0.0136276039257,0.0,0.0,0.0
	.float 0.421227667743,0.345991551981,0.491547939727,0.0,0.0,0.0
	.float 0.547781047732,0.600224422645,0.69353507109,0.0,0.0,0.0
	.float 0.136852623123,0.913625511766,0.516470429041,0.0,0.0,0.0
	.float 0.688728947002,0.814581191279,0.151076919562,0.0,0.0,0.0
	.float 0.733741881363,0.608354997406,0.129079606419,0.0,0.0,0.0
	.float 0.662808925937,0.490475596376,0.532146290505,0.0,0.0,0.0
	.float 0.827667101278,0.15536742888,0.954207194393,0.0,0.0,0.0
	.float 0.426434252139,0.512134290377,0.296417768575,0.0,0.0,0.0
	.float 0.307558439431,0.398986458128,0.3199429037,0.0,0.0,0.0
	.float 0.260876572631,0.548878279691,0.799729059928,0.0,0.0,0.0
	.float 0.161597916179,0.783062109784,0.0694176691853,0.0,0.0,0.0
	.float 0.589713319177,0.786425427727,0.349900719102,0.0,0.0,0.0
	.float 0.756967225221,0.000246889376914,0.837322042677,0.0,0.0,0.0
	.float 0.107739990504,0.96476660431,0.109833701997,0.0,0.0,0.0
	.float 0.567790557761,0.0925564650629,0.684545765882,0.0,0.0,0.0
	.float 0.214320169964,0.586800325669,0.253852235518,0.0,0.0,0.0
	.float 0.398825481949,0.244706702644,0.707315170688,0.0,0.0,0.0
	.float 0.628276442342,0.226920902602,0.431622361479,0.0,0.0,0.0
	.float 0.328145317598,0.613237205149,0.163466454421,0.0,0.0,0.0
	.float 0.0888396762121,0.884610630034,0.0108589790731,0.0,0.0,0.0
	.float 0.563093725928,0.700021946097,0.915715416055,0.0,0.0,0.0
	.float 0.405463725177,0.498906898141,0.358197789661,0.0,0.0,0.0
	.float 0.963246636236,0.777935109842,0.135396991767,0.0,0.0,0.0
	.float 0.67336447231,0.844228926643,0.0468229054805,0.0,0.0,0.0
	.float 0.80828196861,0.952550934867,0.448222466312,0.0,0.0,0.0
	.float 0.233198540744,0.123535110748,0.462089999374,0.0,0.0,0.0
	.float 0.131235632965,0.753397358247,0.301222656589,0.0,0.0,0.0
	.float 0.091907634831,0.406715533806,0.0643767315879,0.0,0.0,0.0
	.float 0.564931048829,0.638773251716,0.362941759937,0.0,0.0,0.0
	.float 0.255591745583,0.765222658927,0.687654287719,0.0,0.0,0.0
	.float 0.141481643576,0.813554295988,0.464040575462,0.0,0.0,0.0
	.float 0.770641407125,0.118010973508,0.0767589701338,0.0,0.0,0.0
	.float 0.193174352712,0.819545845699,0.00480469457562,0.0,0.0,0.0
	.float 0.797719214608,0.584425505574,0.100647714079,0.0,0.0,0.0
	.float 0.575309000785,0.241951804805,0.75675671876,0.0,0.0,0.0
	.float 0.421100562737,0.237006562218,0.259559500384,0.0,0.0,0.0
	.float 0.64461214014,0.280178072737,0.90361558843,0.0,0.0,0.0
	.float 0.252782181364,0.250781275961,0.72590747059,0.0,0.0,0.0
	.float 0.23645167854,0.484964747858,0.663517499194,0.0,0.0,0.0
	.float 0.314205634464,0.769349252995,0.344455593272,0.0,0.0,0.0
	.float 0.482300753529,0.875133317976,0.400266270765,0.0,0.0,0.0
	.float 0.889281573344,0.756493367364,0.938758915315,0.0,0.0,0.0
	.float 0.519196719573,0.572014547589,0.859088244522,0.0,0.0,0.0
	.float 0.467795511757,0.160901504983,0.572078972181,0.0,0.0,0.0
	.float 0.10662007788,0.799485367715,0.287106049901,0.0,0.0,0.0
	.float 0.784301435922,0.421206202976,0.084750102209,0.0,0.0,0.0
	.float 0.521446053938,0.40590701187,0.325090523736,0.0,0.0,0.0
	.float 0.284591143208,0.244945698204,0.599939723729,0.0,0.0,0.0
	.float 0.621159593131,0.181659813562,0.225113225818,0.0,0.0,0.0
	.float 0.449761327301,0.688284021538,0.3173635776,0.0,0.0,0.0
	.float 0.19074177574,0.33535478939,0.231068418134,0.0,0.0,0.0
	.float 0.905139516322,0.965272541049,0.288338610501,0.0,0.0,0.0
	.float 0.729894037302,0.377626638773,0.542127967424,0.0,0.0,0.0
	.float 0.672978999152,0.785760662207,0.337241425973,0.0,0.0,0.0
	.float 0.552891843894,0.536378539306,0.914247841148,0.0,0.0,0.0
	.float 0.0983668013488,0.397335585214,0.572585097348,0.0,0.0,0.0
	.float 0.109201409185,0.332895379216,0.61173289286,0.0,0.0,0.0
	.float 0.499779412909,0.789757480647,0.270110068559,0.0,0.0,0.0
	.float 0.260590606809,0.762683441339,0.31178956038,0.0,0.0,0.0
	.float 0.691382541915,0.629110759442,0.188584293175,0.0,0.0,0.0
	.float 0.455342392284,0.47505651799,0.025058460351,0.0,0.0,0.0
	.float 0.535746568555,0.652931888983,0.505582180025,0.0,0.0,0.0
	.float 0.935170641936,0.425736340212,0.793956713451,0.0,0.0,0.0
	.float 0.67315773367,0.40870916456,0.906660920925,0.0,0.0,0.0
	.float 0.555367870847,0.353583227628,0.429247397561,0.0,0.0,0.0
	.float 0.156189831849,0.0564183637441,0.756285765696,0.0,0.0,0.0
	.float 0.497182475735,0.947303660819,0.122825172156,0.0,0.0,0.0
	.float 0.0786767835114,0.881716583276,0.53289346696,0.0,0.0,0.0
	.float 0.681429028802,0.11196905799,0.315940224661,0.0,0.0,0.0
	.float 0.668581326744,0.476291864998,0.0574473389498,0.0,0.0,0.0
	.float 0.989135419577,0.325195872422,0.503848041967,0.0,0.0,0.0
	.float 0.717273235788,0.968232341596,0.556876374701,0.0,0.0,0.0
	.float 0.340379414183,0.105193130745,0.642505809242,0.0,0.0,0.0
	.float 0.981194676467,0.798660619903,0.683514444978,0.0,0.0,0.0
	.float 0.953895487059,0.0682872160271,0.685161144227,0.0,0.0,0.0
	.float 0.627910775296,0.948363661988,0.924408558478,0.0,0.0,0.0
	.float 0.516422731085,0.269050944192,0.770853219645,0.0,0.0,0.0
	.float 0.438530791116,0.0440733071801,0.861098172732,0.0,0.0,0.0
	.float 0.708864510377,0.787922661633,0.89068790223,0.0,0.0,0.0
							
