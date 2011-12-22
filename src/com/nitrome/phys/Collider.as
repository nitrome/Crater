package com.nitrome.phys {

	import flash.display.Graphics;
	import flash.geom.Rectangle;
	
	/**
	 * A crate-like collision object.
	 *
	 * Collisions are handled recursively, allowing the object to push queues of crates.
	 *
	 * The Collider has several states to reflect how it may need to be handled.
	 *
	 * Colliders introduced to the physics simulation overlapping other Colliders will go into a FLOAT state
	 * to allow them to drift up to the top of whatever stack they are sitting on.
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Collider extends Rectangle {
		
		public var state:int;
		public var active:Boolean;
		public var partition:Partition;
		public var vx:Number;
		public var vy:Number;
		public var parent:Collider;
		public var children:Vector.<Collider>;
		public var cell:Cell;
		public var awake:int;
		public var userData:*;
		
		/* Establishes a minimum movement policy */
		public static const TOLERANCE:Number = 0.0001;
		
		/* Echoing Box2D, colliders sleep when inactive to prevent method calls that aren't needed */
		public static var AWAKE_DELAY:int = 3;
		
		private static var tempCollider:Collider;
		
		// states
		public static const STACK:int = 0;
		public static const FLOAT:int = 1;
		public static const DRAGGED:int = 2;
		
		public static const GRAVITY:Number = 0.5;
		public static const AIR_DAMPING:Number = 0.98;
		public static const SKATE_DAMPING:Number = 0.9;
		public static const FLOAT_SPEED:Number = -Game.SCALE * 0.25;
		
		public function Collider(x:Number=0, y:Number=0, width:Number=0, height:Number=0, partition:Partition = null, active:Boolean = false) {
			super(x, y, width, height);
			this.partition = partition;
			this.active = active;
			state = STACK;
			vx = vy = 0;
			children = new Vector.<Collider>();
			awake = AWAKE_DELAY;
		}
		
		public function main():void{
			if(state == STACK){
				vx *= AIR_DAMPING;
				if(!parent && y + height < partition.bounds.y + partition.bounds.height) vy = vy * AIR_DAMPING + GRAVITY;
				else {
					vx *= SKATE_DAMPING;
					
					// parent objects need to release children that have moved out of range
					if(parent && parent.y > y + height + Partition.INTERVAL_TOLERANCE){
						divorce();
					}
				}
				if(vx) moveX(vx);
				if(vy) moveY(vy);
			} else if(state == FLOAT){
				if(vx){
					vx *= AIR_DAMPING;
					x += vx;
				}
				if(vy){
					vy *= AIR_DAMPING;
					y += vy;
				}
				y += FLOAT_SPEED;
				if(x < partition.bounds.x) x = partition.bounds.x;
				if(y < partition.bounds.y) y = partition.bounds.y;
				if(x + width > partition.bounds.x + partition.bounds.width) (partition.bounds.x + partition.bounds.width) - width;
				if(y + height > partition.bounds.y + partition.bounds.height) (partition.bounds.y + partition.bounds.height) - height;
				if(partition.getCollidersIn(this).length == 0){
					state = STACK;
					partition.addCollider(this);
				}
				awake = AWAKE_DELAY;
			} else if(state == DRAGGED){
				return;
			}
			// will put the collider to sleep if it doesn't move
			if((vx > 0 ? vx : -vx) < TOLERANCE && (vy > 0 ? vy : -vy) < TOLERANCE && (awake)) awake--;
		}
		
		public function drag(vx:Number, vy:Number):void{
			moveX(vx);
			moveY(vy);
			partition.updateCollider(this);
		}
		
		/* =================================================================
		 * Sorting callbacks for colliding with objects in the correct order
		 * =================================================================
		 */
		public function sortLeftWards(a:Collider, b:Collider):Number{
			if(a.x < b.x) return -1;
			else if(a.x > b.x) return 1;
			return 0;
		}
		
		public function sortRightWards(a:Collider, b:Collider):Number{
			if(a.x > b.x) return -1;
			else if(a.x < b.x) return 1;
			return 0;
		}
		
		public function sortTopWards(a:Collider, b:Collider):Number{
			if(a.y < b.y) return -1;
			else if(a.y > b.y) return 1;
			return 0;
		}
		
		public function sortBottomWards(a:Collider, b:Collider):Number{
			if(a.y > b.y) return -1;
			else if(a.y < b.y) return 1;
			return 0;
		}
		
		/* add a child collider to this collider - it will move when this collider moves */
		public function addChild(collider:Collider):void{
			collider.parent = this;
			collider.vy = 0;
			children.push(collider);
		}
		
		/* remove a child collider from children */
		public function removeChild(collider:Collider):void{
			collider.parent = null;
			children.splice(children.indexOf(collider), 1);
			collider.awake = AWAKE_DELAY;
		}
		
		/* Get rid of children and parent - used to remove the collider from the game and clear current interaction */
		public function divorce():void{
			if(parent){
				parent.removeChild(this);
				vy = 0;
			}
			for (var i:int = 0; i < children.length; i++) {
				children[i].parent = null;
				children[i].vy = 0;
				children[i].awake = AWAKE_DELAY;
			}
			children.length = 0;
			awake = AWAKE_DELAY;
		}
		
		public function moveX(vx:Number):Number{
			if(Math.abs(vx) < TOLERANCE) return 0;
			var i:int;
			var obstacles:Vector.<Collider>;
			var shouldMove:Number;
			var actuallyMoved:Number;
			if(vx > 0){
				obstacles = partition.getCollidersIn(new Rectangle(x + width, y, vx, height), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortLeftWards);
				else if(obstacles.length == 2){
					if(obstacles[0].x > obstacles[1].x){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vx may get altered over this loop, we need to still check for overlap
						if(obstacles[i].x < x + width + vx){
							
							//Game.debug.lineStyle(2, 0x00FF00);
							//Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
							//Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
							//Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							//
							//trace("push:");
							//trace(this);
							//trace(obstacles[i]);
							
							shouldMove = (x + width + vx) - obstacles[i].x;
							
							actuallyMoved = obstacles[i].moveX(shouldMove);
							if(actuallyMoved < shouldMove){
								vx -= shouldMove - actuallyMoved;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vx == 0) this.vx = 0;
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(x + width + vx > partition.bounds.x + partition.bounds.width){
					vx -= (x + width + vx) - (partition.bounds.x + partition.bounds.width);
					this.vx = 0;
				}
			} else if(vx < 0){
				obstacles = partition.getCollidersIn(new Rectangle(x + vx, y, -vx, height), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortRightWards);
				else if(obstacles.length == 2){
					if(obstacles[0].x < obstacles[1].x){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vx may get altered over this loop, we need to still check for overlap
						if(obstacles[i].x + obstacles[i].width > x + vx){
							
							//Game.debug.lineStyle(2, 0x00FF00);
							//Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
							//Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
							//Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							
							shouldMove = (x + vx) - (obstacles[i].x + obstacles[i].width);
							actuallyMoved = obstacles[i].moveX(shouldMove);
							if(actuallyMoved > shouldMove){
								vx += actuallyMoved - shouldMove;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vx == 0) this.vx = 0;
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(x + vx < partition.bounds.x){
					vx += partition.bounds.x - (x + vx);
					this.vx = 0;
				}
			}
			x += vx;
			partition.updateCollider(this);
			// if the collider has a parent, check it is still sitting on it
			if(parent && (x + width <= parent.x || x >= parent.x + parent.width)){
				parent.removeChild(this);
			}
			// if the collider has children, check they're still sitting on this
			if(children.length){
				for(i = children.length - 1; i > -1; i--){
					if(children[i].x + children[i].width <= x || children[i].x >= x + width){
						removeChild(children[i]);
					}
				}
			}
			awake = AWAKE_DELAY;
			return vx;
		}
		
		
		public function moveY(vy:Number):Number{
			if(Math.abs(vy) < TOLERANCE) return 0;
			var i:int;
			var obstacles:Vector.<Collider>;
			var shouldMove:Number;
			var actuallyMoved:Number;
			if(vy > 0){
				obstacles = partition.getCollidersIn(new Rectangle(x, y + height, width, vy), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortTopWards);
				else if(obstacles.length == 2){
					if(obstacles[0].y > obstacles[1].y){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this && obstacles[i] != parent){
						
						// the simulation as it stands was adequate for production in Steamlands - further proof
						// of concept for objects pushing downwards is outlined below but not implemented
						// use at own risk
						
						// because the vy may get altered over this loop, we need to still check for overlap
						//if(obstacles[i].y < y + height + vy){
							//shouldMove = (y + height + vy) - obstacles[i].y;
							//actuallyMoved = obstacles[i].moveY(shouldMove);
							//if(actuallyMoved < shouldMove){
								//vy -= shouldMove - actuallyMoved;
								// kill energy when recursively hitting bounds
								//if(obstacles[i].vy == 0) this.vy = 0;
							//}
							// make this Collider a child of the obstacle
							//if(state == STACK && (!parent || (parent && obstacles[i] != parent))){
								//if(parent) parent.removeChild(this);
								//obstacles[i].addChild(this);
							//}
						//} else break;
						//
						//Game.debug.lineStyle(2, 0x00FF00);
						//Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
						//Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
						//Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
						
						
						vy = obstacles[i].y - (y + height);
						if(state == STACK && (!parent || (parent && obstacles[i] != parent))){
							if(parent) parent.removeChild(this);
							obstacles[i].addChild(this);
						}
						break;
						
						
					}
				}
				// now check against the edge of the map
				if(y + height + vy > partition.bounds.y + partition.bounds.height){
					vy -= (y + height + vy) - (partition.bounds.y + partition.bounds.height);
					this.vy = 0;
				}
			} else if(vy < 0){
				obstacles = partition.getCollidersIn(new Rectangle(x, y + vy, width, -vy), this);
				// small optimisation here - sorting needs to be avoided
				if(obstacles.length > 2 ) obstacles.sort(sortBottomWards);
				else if(obstacles.length == 2){
					if(obstacles[0].y < obstacles[1].y){
						tempCollider = obstacles[0];
						obstacles[0] = obstacles[1];
						obstacles[1] = tempCollider;
					}
				}
				for(i = 0; i < obstacles.length; i++){
					if(obstacles[i] != this){
						// because the vy may get altered over this loop, we need to still check for overlap
						if(obstacles[i].y + obstacles[i].height > y + vy){
							
							//Game.debug.lineStyle(2, 0x00FF00);
							//Game.debug.drawCircle(x + width * 0.5, y + height * 0.5, 10);
							//Game.debug.moveTo(x + width * 0.5, y + height * 0.5);
							//Game.debug.lineTo(obstacles[i].x + obstacles[i].width * 0.5, obstacles[i].y + obstacles[i].height * 0.5);
							
							shouldMove = (y + vy) - (obstacles[i].y + obstacles[i].height);
							actuallyMoved = obstacles[i].moveY(shouldMove);
							if(actuallyMoved > shouldMove){
								vy += actuallyMoved - shouldMove;
								// kill energy when recursively hitting bounds
								if(obstacles[i].vy == 0) this.vy = 0;
							}
							// make the obstacle a child of this Collider
							if(obstacles[i].state == STACK && (!obstacles[i].parent || (obstacles[i].parent && obstacles[i].parent != this))){
								if(obstacles[i].parent) obstacles[i].parent.removeChild(obstacles[i]);
								addChild(obstacles[i]);
							}
						} else break;
					}
				}
				// now check against the edge of the map
				if(y + vy < partition.bounds.y){
					vy += partition.bounds.y - (y + vy);
					this.vy = 0;
				}
			}
			y += vy;
			partition.updateCollider(this);
			// move children - ie: blocks stacked on top of this Collider
			// children should not be moved when travelling up - this Collider is already taking care of that
			// by pushing them
			if(vy > 0){
				for(i = 0; i < children.length; i++){
					children[i].moveY(vy);
				}
			}
			awake = AWAKE_DELAY;
			return vy;
		}
		
		/* Draw debug diagram */
		public function draw(gfx:Graphics):void{
			gfx.lineStyle(2, 0xFFFF00);
			gfx.drawRect(x, y, width, height);
			if(awake){
				gfx.drawRect(x + 5, y + 5, width - 10, height - 10);
			}
			if(parent != null){
				gfx.moveTo(x + width * 0.5, y + height * 0.5);
				gfx.lineTo(parent.x, parent.y);
			}
			//gfx.lineStyle(1, 0x00FF00);
			//for(var i:int = 0; i < cells.length; i++){
				//gfx.drawRect(cells[i].x * partition.scale, cells[i].y * partition.scale, partition.scale, partition.scale);
			//}
			//gfx.drawRect(cell.x * partition.scale, cell.y * partition.scale, partition.scale * 2, partition.scale * 2);
			//gfx.lineTo(cell.x * partition.scale, cell.y * partition.scale);
		}
	}
}