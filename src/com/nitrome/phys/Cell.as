package com.nitrome.phys {
	
	/**
	 * A unit in the Partition. Exists only when it has Colliders in it to keep memory down.
	 *
	 * @author Aaron Steed, nitrome.com
	 */
	public class Cell {
		
		public var x:int;
		public var y:int;
		public var colliders:Vector.<Collider>;

		public function Cell(x:int, y:int) {
			this.x = x;
			this.y = y;
			colliders = new Vector.<Collider>();
		}
	}
}