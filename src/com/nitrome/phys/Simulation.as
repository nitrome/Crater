package com.nitrome.phys{
	import flash.display.Graphics;
	import flash.geom.Rectangle;
	
	/**
	 * Management object for a physics simulation
	 *
	 * Colliders are generated with this object to ensure that they are propagated to the Partition or
	 * set to FLOAT if overlapping
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Simulation{
		
		public var bounds:Rectangle;
		public var partition:Partition;
		public var colliders:Vector.<Collider>;
		public var floaters:Vector.<Collider>;
		public var shockwaves:Vector.<Shockwave>;
		
		public var debug:Graphics;
		
		protected static var i:int;
		
		public function Simulation(bounds:Rectangle, cellScale:Number){
			this.bounds = bounds;
			partition = new Partition(Math.ceil(bounds.width / cellScale), Math.ceil(bounds.height / cellScale), cellScale, bounds);
			colliders = new Vector.<Collider>();
			shockwaves = new Vector.<Shockwave>();
			floaters = new Vector.<Collider>();
		}
		
		public function main():void{
			if(shockwaves.length){
				for(i = 0; i < shockwaves.length; i++){
					shockwaves[i].execute();
				}
				if(debug){
					for(i = 0; i < shockwaves.length; i++){
						shockwaves[i].draw(debug);
					}
				}
				shockwaves.length = 0;
			}
			for(i = 0; i < colliders.length; i++){
				if(colliders[i].awake) colliders[i].main();
			}
			if(floaters.length) floaters.filter(floaterCallBack);
			if(debug){
				for(i = 0; i < colliders.length; i++){
					colliders[i].draw(debug);
				}
			}
		}
		
		private function floaterCallBack(item:Collider, index:int, list:Vector.<Collider>):Boolean{
			return item.state == Collider.FLOAT;
		}
		
		/* Creates a new Collider in the simulation */
		public function addCollider(x:Number, y:Number, width:Number, height:Number):Collider{
			// force the collider to be in the bounds of the map
			if(x < bounds.x) x = bounds.x;
			if(y < bounds.y) y = bounds.y;
			if(x + width > bounds.x + bounds.width) x = (bounds.x + bounds.width) - width;
			if(y + height > bounds.y + bounds.height) y = (bounds.y + bounds.height) - height;
			var collider:Collider = new Collider(x, y, width, height, partition, true);
			colliders.push(collider);
			if(partition.getCollidersIn(collider).length){
				collider.state = Collider.FLOAT;
				floaters.push(collider);
			} else {
				partition.addCollider(collider);
			}
			trace(colliders.length);
			return collider;
		}
		
		/* Removes a Collider from the simulation */
		public function removeCollider(collider:Collider):void{
			collider.divorce();
			colliders.splice(colliders.indexOf(collider), 1);
			partition.removeCollider(collider);
		}
		
		/* Adds a shockwave effect to be applied on the next frame */
		public function addShockwave(x:Number, y:Number, radius:Number, velocity:Number, step:Number):void{
			shockwaves.push(new Shockwave(x, y, radius, velocity, step, this));
		}
		
		/* Picks out a collider from all colliders available by also checking the floaters list */
		public function getColliderAt(x:Number, y:Number):Collider{
			for(var i:int = 0; i < floaters.length; i++){
				if(floaters[i].contains(x, y)) return floaters[i];
			}
			return partition.getColliderAt(x, y);
		}
		
		/* Return all the Colliders that touch the rectangle "area" */
		public function getCollidersIn(area:Rectangle, ignore:Collider = null):Vector.<Collider>{
			var result:Vector.<Collider> = partition.getCollidersIn(area, ignore);
			var collider:Collider;
			for(var i:int = 0; i < floaters.length; i++){
				collider = floaters[i];
				
				// floating point error causes a lot of false positives, so that's
				// why I'm using a tolerance value to ignore those drifting values
				// at the end of the Number datatype
				if(collider != ignore &&
					collider.x + collider.width - Partition.INTERVAL_TOLERANCE > area.x &&
					collider.y + collider.height - Partition.INTERVAL_TOLERANCE > area.y &&
					area.x + area.width - Partition.INTERVAL_TOLERANCE > collider.x &&
					area.y + area.height - Partition.INTERVAL_TOLERANCE > collider.y
				){
					result.push(collider);
				}
			}
			return result;
		}
	}
}