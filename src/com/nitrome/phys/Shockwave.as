package com.nitrome.phys{
	
	import flash.display.Graphics;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	/**
	 * Throws Colliders away from its epicenter. Used to simulate explosions
	 *
	 * The object exists for one frame only and executes one the frame after it has been called.
	 * This is to allow the stage to be set with the necessary items to throw whilst adding in
	 * the required shockwaves at the same time.
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Shockwave extends Point{
		
		protected var sim:Simulation;
		public var radius:Number;
		public var v:Number;
		public var step:Number;
		public var decay:Number;
		
		public function Shockwave(x:Number, y:Number, radius:Number, velocity:Number, step:Number, sim:Simulation){
			super(x, y);
			this.radius = radius;
			this.step = step;
			this.decay = decay;
			this.sim = sim;
			v = velocity / (radius / step);
		}
		
		/* Applies the effect of the shockwave to all the Colliders within its radius */
		public function execute():void{
			var mapX:int, mapY:int;
			var r:int, c:int, i:int;
			var vx:Number, vy:Number;
			var colliders:Vector.<Collider>;
			var length:Number;
			for(var dist:Number = radius; dist > 0; dist -= step){
				colliders = sim.getCollidersIn(new Rectangle(x - dist, y - dist, dist * 2, dist * 2));
				for(i = 0; i < colliders.length; i++){
					vx = x - (colliders[i].x + colliders[i].width * 0.5);
					vy = y - (colliders[i].y + colliders[i].height * 0.5);
					length = vx * vx + vy * vy;
					if(length <= dist * dist){
						// get the normal so we can shove this object
						if(length){
							length = Math.sqrt(length);
							vx /= length;
							vy /= length;
							colliders[i].vx -= vx * v;
							colliders[i].vy -= vy * v;
							if(colliders[i].parent || colliders[i].children.length){
								colliders[i].divorce();
							}
							colliders[i].awake = Collider.AWAKE_DELAY;
						}
					}
				}
			}
		}
		
		public function draw(gfx:Graphics):void{
			gfx.lineStyle(1, 0xFF0000);
			gfx.drawCircle(x, y, radius);
		}
	}
}