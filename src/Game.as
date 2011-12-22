package{
	
	import com.nitrome.phys.Collider;
	import com.nitrome.phys.Partition;
	import com.nitrome.phys.Simulation;
	
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.display.Graphics;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.ui.Keyboard;
	import flash.utils.Timer;
	
	[SWF(width = "640", height = "480", frameRate="30", backgroundColor = "#000000")]
	
	public class Game extends Sprite{
		
		public var sim:Simulation;
		public var draggedCollider:Collider;
		public var dragOffsetX:Number;
		public var dragOffsetY:Number;
		public var clicker:Sprite;
		public var bitmap:Bitmap;
		public var vx:Number;
		public var vy:Number;
		public var keyPressed:Boolean;
		public var keyCount:int;
		public var frameCount:int;
		public var keys:Array = [];
		public var lastCollider:Collider;
		public var fps:TextField;
		
		public var timer:Timer;
		public var fpsFrames:int = 0;
		
		public static var debug:Graphics;
		public static var debugStay:Graphics;
		
		public static const SCALE:Number = 20;
		public static const INV_SCALE:Number = 1.0 / SCALE;
		public static const WIDTH:Number = 640;
		public static const HEIGHT:Number = 480;
		// this value is so large because my game has a block that is 6 units wide unfortunately
		public static const CELL_SCALE:Number = 120;
		
		public static const CRATE_SIZE:Number = 20;
		
		public function Game(){
			bitmap = new Bitmap(new BitmapData(WIDTH, HEIGHT, true, 0x00000000));
			addChild(bitmap);
			var debugShape:Shape = new Shape();
			addChild(debugShape);
			debug = debugShape.graphics;
			fps = new TextField();
			fps.width = 200;
			fps.height = 200;
			fps.defaultTextFormat = new TextFormat(null, 14, 0xCCCCCC, true);
			addChild(fps);
			timer = new Timer(1000);
			timer.addEventListener(TimerEvent.TIMER, tick);
			timer.start();
			clicker = new Sprite();
			clicker.graphics.beginFill(0, 0);
			clicker.graphics.drawRect(0, 0, WIDTH, HEIGHT);
			clicker.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
			clicker.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
			addChild(clicker);
			sim = new Simulation(new Rectangle(0, 0, WIDTH, HEIGHT), CELL_SCALE);
			
			addEventListener(Event.ENTER_FRAME, main);
			addEventListener(Event.ADDED_TO_STAGE, addedToStage);
			
			//sim.debug = debug;
			var r:int, c:int;
			for(r = 0; r < 120; r += CRATE_SIZE){
				for(c = 0; c < WIDTH; c += CRATE_SIZE){
					sim.addCollider(c, r, CRATE_SIZE, CRATE_SIZE);
				}
			}
		}
		
		public function addedToStage(e:Event):void{
			stage.addEventListener(KeyboardEvent.KEY_DOWN, keyDown);
			stage.addEventListener(KeyboardEvent.KEY_UP, keyUp);
		}
		
		public function main(e:Event):void{
			if(keyPressed && lastCollider){
				var speed:Number = 2;
				lastCollider.awake = Collider.AWAKE_DELAY;
				if(keys[87]){//w
					lastCollider.vy -= speed;
					trace("up vy:"+lastCollider.vy);
				}
				if(keys[83]){//s
					lastCollider.vy += speed;
					trace("down vy:"+lastCollider.vy);
				}
				if(keys[65]){//a
					lastCollider.vx -= speed;
					trace("left vx:"+lastCollider.vx);
				}
				if(keys[68]){//d
					lastCollider.vx += speed;
					trace("right vx:"+lastCollider.vx);
				}
				if(keyCount == frameCount && keys[Keyboard.SPACE]){
					sim.addShockwave(mouseX, mouseY, 80, 20, SCALE);
				}
			}
			//if(lastCollider) lastCollider.vx += 0.001;
			
			var i:int;
			debug.clear();
			if(draggedCollider){
				vx = (mouseX - dragOffsetX) - draggedCollider.x;
				vy = (mouseY - dragOffsetY) - draggedCollider.y;
				draggedCollider.drag(vx, vy);
			}
			sim.main();
			// render
			bitmap.bitmapData.fillRect(bitmap.bitmapData.rect, 0x00000000);
			var rect:Rectangle = new Rectangle(0, 0, SCALE - 2, SCALE - 2);
			for(i = 0; i < sim.colliders.length; i++){
				bitmap.bitmapData.fillRect(sim.colliders[i], 0xFFFFFFFF);
				rect.x = sim.colliders[i].x + 1;
				rect.y = sim.colliders[i].y + 1;
				bitmap.bitmapData.fillRect(rect, 0xFFCCCCCC);
			}
			frameCount++;
			fpsFrames++;
		}
		
		private function mouseDown(e:MouseEvent):void{
			// add a new Collider to the map if not clicking on one
			// otherwise drag a Collider
			var collider:Collider = sim.partition.getColliderAt(mouseX, mouseY);
			if(collider){
				draggedCollider = collider;
				draggedCollider.divorce();
				dragOffsetX = mouseX - draggedCollider.x;
				dragOffsetY = mouseY - draggedCollider.y;
				draggedCollider.state = Collider.DRAGGED;
				return;
			}
			lastCollider = sim.addCollider(mouseX - CRATE_SIZE * 0.5, mouseY - CRATE_SIZE * 0.5, CRATE_SIZE, CRATE_SIZE);
		}
		
		private function mouseUp(e:MouseEvent):void{
			if(draggedCollider){
				draggedCollider.state = Collider.STACK;
				draggedCollider.vx = vx;
				draggedCollider.vy = vy;
				draggedCollider = null;
			}
		}
		
		private function keyDown(e:KeyboardEvent):void{
			keyPressed = true;
			keyCount = frameCount;
			keys[e.keyCode] = true;
		}
		
		private function keyUp(e:KeyboardEvent):void{
			keyPressed = false;
			keys = [];
		}
		
		private function tick(e:TimerEvent):void{
			fps.text = "fps:" + fpsFrames + " crates:" + sim.colliders.length;
			fpsFrames = 0;
		}
	}
}