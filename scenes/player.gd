extends KinematicBody2D
class_name Player

enum States {Idle, Moving, OnAir, GroundPound, Locked, Died, Won}
export(States) var state = States.Idle setget _setState
func _setState(value) -> void:
	state = value
	
	if state == States.GroundPound:
		AudioManager.playSfx(AudioManager.sfxPlayerGroundPound)
		vVelocity = Vector2()
		twnSquish()
	elif state == States.Died:
		AudioManager.playSfx(AudioManager.sfxPlayerHurt)
		self.set_collision_layer_bit(0, false)
		self.set_collision_mask_bit(0, false)
	elif state == States.Won:
		AudioManager.playSfxWithoutPitchShift(AudioManager.sfxPlayerStarGet)
		nAnimationPlayer.play("win")
		yield(nAnimationPlayer, 'animation_finished')
		global.idxCurrentLevel += 1
		strNextLevel = global.arrLevels[global.idxCurrentLevel]
		global.changeSceneTo(strNextLevel)

export(bool) var bCanFlip := false
export(String) var strNextLevel:String = "res://scenes/debugRoot.tscn"

const scnFxPlayerJumpDust := preload("res://scenes/fxPlayerJumpDust.tscn")
const scnFxPlayerLandDust := preload("res://scenes/fxPlayerLandDust.tscn")
const scnFxPlayerLandDustBigger := preload("res://scenes/fxPlayerLandDustBigger.tscn")
const scnFxPlayerRunDust := preload("res://scenes/fxPlayerWalkDust.tscn")

signal sgnDied
var vInitialGlobalPosition := Vector2()
var vVelocity := Vector2()
var fSpeed := 100.0
var fMaxSpeed := 500.0
var fGravity := 1200.0
var vGravity := Vector2(0,1)
var vTargetGravity := Vector2(0,1)
var bSlowTurn := false
var vFloorNormal := Vector2(0,-1) setget _setFloorNormal
func _setFloorNormal(value) -> void:
	self.vGravity = -value.normalized()
	self.rotation = vGravity.angle() - PI/2
	
	if bSlowTurn:
		nSprite.rotation += (PI/2 if !bSlowTurn else PI) * (1 if nRcFront.is_colliding() else -1) * sign(fSpeed)
	
	var _v = nTwn.interpolate_property(nSprite,'rotation', nSprite.rotation if bSlowTurn else nSprite.rotation + (PI/2 if !bSlowTurn else PI) * (1 if nRcFront.is_colliding() else -1) * sign(fSpeed), 0, 0.2, Tween.TRANS_SINE, Tween.EASE_OUT)
	_v = nTwn.start()
	
	if bSlowTurn:
		bSlowTurn = false
	
	vFloorNormal = value
	
var fJumpForce := 280.0#250.0
var bJumped := false
var t := 0
var bWasRcFrontColliding := false
var bWasRcLeftColliding := false
var bWasRcRightColliding := false
var strCurrentAnimation := 'idle'
var fSpriteAngle := 0

onready var nTwn:Tween = $tween
onready var nTwnSquish:Tween = $tweenSquish
onready var nSprite:Sprite = $sprite
onready var nColShape2d:CollisionShape2D = $collisionShape2D
onready var nRcFront:RayCast2D = $rcFront
onready var nRcLeft:RayCast2D = $rcFloorLeft
onready var nRcRight:RayCast2D = $rcFloorRight
onready var nAnimationPlayer:AnimationPlayer = $animationPlayer
onready var nRcGravity:RayCast2D = $rcGravity
onready var nRcTargetGravity:RayCast2D = $rcTargetGravity
onready var nRcFloorCheck:RayCast2D = $rcFloorCheck
onready var nArea2d:Area2D = $area2D
onready var nSpriteAmogus:Sprite = $spriteAmogus

func _ready() -> void:
	bCanFlip = global.bPlayerCanFlip
	bCanFlip = true
	
	#strNextLevel = global.arrLevels[global.idxCurrentLevel]
	
	if randf() <= 0.01:
		nSprite.visible = false
		nSpriteAmogus.visible = true
#	if bCanFlip:
#		nSprite.texture = load("res://resources/textures/playerWithFlip.png")
#
	vInitialGlobalPosition = self.global_position
	set_physics_process(true)

func _physics_process(delta: float) -> void:
#	if Input.is_action_just_pressed('ui_debug'):
#		self.state = States.Won
	
	if state == States.Won:
		fnStateWon(delta)
		return
	
	vVelocity.x = clamp(vVelocity.x, -fMaxSpeed, fMaxSpeed)
	vVelocity.y = clamp(vVelocity.y, -fMaxSpeed, fMaxSpeed)
	
	nRcGravity.cast_to = vGravity.rotated(-self.rotation) * 32
	nRcTargetGravity.cast_to = vFloorNormal.rotated(-self.rotation) * 64
	
	t += 1
	if t%10 == 0:
		pass
	vVelocity += vGravity*fGravity*delta
	nRcLeft.force_raycast_update()
	nRcFront.force_raycast_update()
	handleRotation()

#	fSpriteAngle = lerp(fSpriteAngle, self.rotation, 0.1)
#	nSprite.rotation = fSpriteAngle

	var bWasOnFloor = is_on_floor()
	
	match state:
		States.Died:
			strCurrentAnimation = 'dead'
			fnStateDied(delta)
		States.Locked:
			strCurrentAnimation = 'onAir'
			fnStateLocked(delta)
		States.Idle:
			strCurrentAnimation = 'idle'
			fnStateIdle(delta)
			
		States.Moving:
			strCurrentAnimation = 'run'
			fnStateMoving(delta)
			
		States.OnAir:
			strCurrentAnimation = 'onAir'
			fnStateOnAir(delta)
			
		States.GroundPound:
			strCurrentAnimation = 'onAir'
			fnStateGroundPound(delta)
	
	if !bWasOnFloor and is_on_floor():
		createLandDust()
	
	if strCurrentAnimation != nAnimationPlayer.current_animation:
		nAnimationPlayer.play(strCurrentAnimation)
	
	bWasRcFrontColliding = nRcFront.is_colliding()
	bWasRcRightColliding = nRcRight.is_colliding()
	bWasRcLeftColliding = nRcLeft.is_colliding()

func fnStateWon(delta: float) -> void:
	vVelocity = vVelocity.linear_interpolate(Vector2(0,0), 0.1)
	vVelocity += vGravity*fGravity*delta
	vVelocity += vGravity*fGravity*delta
	
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())

func fnStateDied(delta: float) -> void:
	vVelocity = vVelocity.linear_interpolate(Vector2(0,0), 0.1)
	vVelocity += vGravity*fGravity*delta
	
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	self.rotation += delta * 3


func fnStateLocked(delta: float) -> void:
	vVelocity = vVelocity.linear_interpolate(Vector2(0,0), 0.1)
	vVelocity += vGravity*fGravity*delta
	
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	if self.is_on_floor():
		AudioManager.playSfx(AudioManager.sfxPlayerLand)
		self.state = States.Idle
		global.nMainCamera.minorShake()
		return

func fnStateIdle(delta: float) -> void:
	vVelocity = vVelocity.linear_interpolate(Vector2(0,0), 0.33)
	vVelocity += vGravity*fGravity*delta
	
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	if !self.is_on_floor():
		self.state = States.OnAir
		return
	
	if Input.is_action_just_pressed("btn_main"):
		self.state = States.Moving
		return
		
func fnStateMoving(delta: float) -> void:
	vVelocity = fSpeed * Vector2(1,0).rotated(self.rotation)
	vVelocity += vGravity*fGravity*delta
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	if vVelocity != Vector2():
		nSprite.visible = true
		nSpriteAmogus.visible = false
		
	if Input.is_action_just_released("btn_main"):
		jump()
		self.state = States.OnAir
		return
		
func fnStateOnAir(_delta: float) -> void:
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	if Input.is_action_just_pressed("btn_main"):
		self.state = States.GroundPound
		return
	
	if is_on_floor():
		AudioManager.playSfx(AudioManager.sfxPlayerLand)
		bJumped = false
		state = States.Idle
		twnLandSquish()
#		createLandDust()
		return
		
func fnStateGroundPound(delta: float) -> void:
	vVelocity += vGravity*fGravity*delta*4
	vVelocity = move_and_slide(vVelocity, -vGravity.normalized())
	
	if is_on_floor():
		AudioManager.playSfx(AudioManager.sfxPlayerLand)
		bJumped = false
		self.state = States.Idle
		global.nMainCamera.minorShake()
		createLandDustBigger()
		twnLandSquish()
		flipDirection()
		AudioManager.playSfx(AudioManager.sfxPlayerGroundPoundLand)
		return
	
	return

func flipDirection() -> void:
	if !bCanFlip:
		return
		
	nSprite.flip_h = !nSprite.flip_h
	fSpeed *= -1
	nRcLeft.position.x *= -1
	nRcFront.position.x *= -1
	nRcFront.cast_to.x *= -1

func handleMovement(_delta:float) -> void:
	pass

func handleRotation() -> void:
	if bJumped:
		return
		
	if state != States.Moving:
		return
	
	if nTwn.is_active():
		return
	
	# Wall ahead
	if nRcLeft.is_colliding() and nRcFront.is_colliding():
		self.vFloorNormal = nRcFront.get_collision_normal()
	
	# No floor ahead
	elif bWasRcLeftColliding and !nRcLeft.is_colliding():
		self.vFloorNormal = vFloorNormal.rotated(sign(fSpeed)*PI/2)

func createRunDust(fScaleMultiplier:float = 1) -> void:
	var i := scnFxPlayerRunDust.instance()
	i.global_position = self.global_position - Vector2(0, 16).rotated(self.rotation)
	i.rotation = self.rotation
	i.scale *= fScaleMultiplier
	get_parent().add_child(i)

func createLandDust(fScaleMultiplier:float = 1) -> void:
	var i := scnFxPlayerLandDust.instance()
	i.global_position = self.global_position - Vector2(0, 16).rotated(self.rotation)
	i.rotation = self.rotation
	i.scale *= fScaleMultiplier
	get_parent().add_child(i)
	
func createLandDustBigger(fScaleMultiplier:float = 1) -> void:
	var i := scnFxPlayerLandDustBigger.instance()
	i.global_position = self.global_position - Vector2(0, 16).rotated(self.rotation)
	i.rotation = self.rotation
	i.scale *= fScaleMultiplier
	get_parent().add_child(i)

func createJumpDust() -> void:
	var i := scnFxPlayerJumpDust.instance()
	i.global_position = self.global_position - Vector2(0, 16).rotated(self.rotation)
	i.rotation = self.rotation
	get_parent().add_child(i)

func jump(fMultiplier:float = 1) -> void:
	bJumped = true
	self.vVelocity -= vGravity * fJumpForce * fMultiplier
	twnSquish()
	createJumpDust()
	AudioManager.playSfx(AudioManager.sfxPlayerJump)
	return

func twnSquish() -> void:
	var _v = nTwnSquish.interpolate_property(nSprite, 'scale', Vector2(0.5, 1.5), Vector2.ONE, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT)
	_v = nTwnSquish.start()
	
func twnLandSquish() -> void:
	var _v = nTwnSquish.interpolate_property(nSprite, 'scale', Vector2(1.6, 0.4), Vector2.ONE, 0.5, Tween.TRANS_BACK, Tween.EASE_OUT)
	_v = nTwnSquish.start()

func respawn() -> void:
	emit_signal('sgnDied')
	self.rotation = 0
	self.bJumped = false
	self.state = States.Locked
	self.vVelocity = Vector2()
	self.vFloorNormal = Vector2(0,-1)
	self.set_collision_layer_bit(0, true)
	self.set_collision_mask_bit(0, true)
	self.global_position = self.vInitialGlobalPosition
	
	if nSprite.flip_h:
		flipDirection()

func _on_visibilityNotifier2D_screen_exited() -> void:
	if state == States.Won:
		return
	
	yield(get_tree().create_timer(0.33), "timeout")
	respawn()

func _on_area2D_body_entered(body: Node) -> void:
	if state == States.Died:
		return
		
	if state == States.Won:
		return
	
	if body.is_in_group('Blob'):
		if state == States.GroundPound:
			body.steppedOn()
			self.state = States.OnAir
			jump(5)
	elif body.is_in_group('AngryBlob'):
		if state == States.GroundPound:
			AudioManager.playSfx(AudioManager.sfxPlayerLandOnSlime)
			body.steppedOn()
			self.state = States.OnAir
			jump(5)
			bSlowTurn = true
			yield(get_tree().create_timer(0.1),"timeout")
			self.vFloorNormal = self.vFloorNormal.rotated(PI)
	elif body.is_in_group('Enemy'):
		global.nMainCamera.minorShake()
		self.vVelocity = vFloorNormal * 3 * fJumpForce
		self.state = States.Died
	elif body.is_in_group('Spike'):
		global.nMainCamera.minorShake()
		self.vVelocity = vFloorNormal * 3 * fJumpForce
		self.state = States.Died
	elif body.is_in_group('Exit'):
		self.state = States.Won
	elif body.is_in_group('StarPiece'):
		AudioManager.playSfx(AudioManager.sfxPlayerStarPieceGet)
		body.emit_signal('sgnCollected')
	elif body.is_in_group('Upgrade'):
		if body.has_method('disappear'):
			body.disappear()
		global.bPlayerCanFlip = true
		bCanFlip = true
		nSprite.texture = load("res://resources/textures/playerWithFlip.png")
		
func createFootstepSfx() -> void:
	AudioManager.playSfx(AudioManager.sfxPlayerFootstep)
