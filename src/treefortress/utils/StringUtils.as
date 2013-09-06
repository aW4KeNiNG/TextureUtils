/**
 * Created by Pablo, 3DVista
 * Date: 14/08/13
 * Time: 12:44
 */
package treefortress.utils {

    public class StringUtils 
    {
        public static function getNumberFormatted(number:int, toMaxDigits:int = 4):String
        {
            var array:Array = String(number).split("");
            var ceroCount:int = toMaxDigits - array.length;
            for(var i:int = 0; i<ceroCount; i++)
                array.unshift("0");

            return array.join("");
        }
    }
}
