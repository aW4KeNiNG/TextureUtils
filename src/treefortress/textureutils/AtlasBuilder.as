package treefortress.textureutils
{
	import flash.display.Bitmap;
	import flash.display.BitmapData;
	import flash.geom.Matrix;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getTimer;
	import starling.core.Starling;
	import starling.display.Image;
	
	import starling.textures.Texture;
	import starling.textures.TextureAtlas;
	
	public class AtlasBuilder
	{
		public static var packTime:int;
		public static var atlasBitmap:BitmapData;
		public static var atlasXml:XML;
		
		public function AtlasBuilder()
		{
		}
		
		public static function build(bitmapList:Vector.<Bitmap>, scale:Number = 1, padding:int = 2, extrusion:int = 1, width:int = 2048, height:int = 2048):TextureAtlas
		{
			
			var t:int = getTimer();
			
			atlasBitmap = new BitmapData(width, height, true, 0x0);
			var packer:MaxRectPacker = new MaxRectPacker(width, height);
			var atlasText:String = "";
			var bitmap:Bitmap, name:String, rect:Rectangle, subText:String, m:Matrix = new Matrix();
			
			for (var i:int = 0; i < bitmapList.length; i++)
			{
				bitmap = bitmapList[i];
				bitmap = extrude(bitmap, extrusion);
				bitmapList[i] = bitmap;
				name = bitmapList[i].name;
				rect = packer.quickInsert((bitmap.width * scale) + padding * 2, (bitmap.height * scale) + padding * 2);
				
				//Add padding
				rect.x += padding;
				rect.y += padding;
				rect.width -= padding * 2;
				rect.height -= padding * 2;
				
				//Apply scale
				if (!rect)
				{
					trace("Texture Limit Exceeded");
					continue;
				}
				
				m.identity();
				m.scale(scale, scale);
				m.translate(rect.x, rect.y);
				atlasBitmap.draw(bitmapList[i], m);
				
				//Create XML line item for TextureAtlas
				subText = '<SubTexture name="' + name + '" ' + 'x="' + rect.x + '" y="' + rect.y + '" width="' + rect.width + '" height="' + rect.height + '" frameX="3" frameY="3" ' + 'frameWidth="' + (rect.width - 3) + '" frameHeight="' + (rect.height - 3) + '"/>';
				atlasText = atlasText + subText;
			}
			
			//Create XML from text (much faster than working with an actual XML object)
			atlasText = '<TextureAtlas imagePath="atlas.png">' + atlasText + "</TextureAtlas>";
			atlasXml = new XML(atlasText);
			
			//Create the atlas
			var texture:Texture = Texture.fromBitmapData(atlasBitmap, false);
			var atlas:TextureAtlas = new TextureAtlas(texture, atlasXml);
			
			//Save elapsed time in case we're curious how long this took
			packTime = getTimer() - t;
			
			return atlas;
		}
		
		private static function extrude(bitmap:Bitmap, extrude:int = 1):Bitmap
		{
			var newBitmapData:BitmapData = new BitmapData(bitmap.width + (extrude * 2), bitmap.height + (extrude * 2), true, 0x00FFFFFF);
			newBitmapData.copyPixels(bitmap.bitmapData, new Rectangle(0, 0, bitmap.width, bitmap.height), new Point(extrude, extrude), null, null, true);
			
			// Top and bottom			
			for (var i:int = 1; i < newBitmapData.width - 1; ++i)
			{
				newBitmapData.setPixel32(i, 0, newBitmapData.getPixel32(i, 1));
				newBitmapData.setPixel32(i, newBitmapData.height - 1, newBitmapData.getPixel32(i, newBitmapData.height - 2));
			}
			
			// Left and right
			for (i = 0; i < newBitmapData.height - 1; ++i)
			{
				newBitmapData.setPixel32(0, i, newBitmapData.getPixel32(1, i));
				newBitmapData.setPixel32(newBitmapData.width - 1, i, newBitmapData.getPixel32(newBitmapData.width - 2, i));
			}
			
			var newBitmap:Bitmap = new Bitmap(newBitmapData);
			newBitmap.name = bitmap.name;
			
			return newBitmap;
		}
	}
}
