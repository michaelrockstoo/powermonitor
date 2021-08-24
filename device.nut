#require "HTS221.device.lib.nut:2.0.1"
//
// =============================================================================
// UInt64 ----------------------------------------------------------------------
// ============================================================================{
// Copyright (c) 2019 Eaton
// Copyright (c) 2013 Pierre Curto
//
// Created:  2019-05-22
//
// Ported from:
// https://github.com/pierrec/js-cuint/blob/master/lib/uint64.js

class uint64 {
    static _createStringValues = [];
    static _largestQuickStringNumber = [];

    _remainder = null;
    _a00 = null;
    _a16 = null;
    _a32 = null;
    _a48 = null;

    minus = null;
    sub = null;
    plus = null;
    mul = null;
    times = null;
    valueOf = null;
    toJSON = null;
    _string = null;             // holds the most up to date string representation of the uint64
                                // (so we don't have to do uint64 _encode math when we want the string)

    static function _initCreateStringValues() {
        local zero = uint64(0);
        local pow10 = uint64(1);

        for (local exp = 0; exp < 19; ++exp) {
        local values = [zero];
        values.push(pow10);
        for (local mul = 2; mul <= 9; ++mul) {
            values.push(pow10.mul(mul));
        }
        _createStringValues.push(values);
        pow10 = pow10.mul(10);
        }

        _createStringValues.push([zero, pow10]);
        _largestQuickStringNumber.push(uint64("9000000000000000000"));
    }

    /**
    *	Represents an unsigned 64 bits integer
    * @constructor
    * @param {Number} first low bits (8)
    * @param {Number} second low bits (8)
    * @param {Number} first high bits (8)
    * @param {Number} second high bits (8)
    * or
    * @param {Number} low bits (32)
    * @param {Number} high bits (32)
    * or
    * @param {String|Number} integer as a string 		 | integer as a number
    * @param {Number|Undefined} radix (optional, default=10)
    * @return
    */
    constructor(a00=null, a16=null, a32=null, a48=null) {
        this.minus      = this.subtract;
        this.sub        = this.subtract;
        this.plus       = this.add;
        this.times      = this.multiply;
        this.mul        = this.multiply;
        this._remainder = null

        if(a00 instanceof uint64){
            this._a00 = a00._a00;
            this._a16 = a00._a16;
            this._a32 = a00._a32;
            this._a48 = a00._a48;
            this._remainder = a00._remainder;
            this._string = a00._string;
            return this;
        }

        if(a00 == null){
            this._a00 = 0;
            this._a16 = 0;
            this._a32 = 0;
            this._a48 = 0;
            this._string = "0";
            return this;
        }

        if(typeof a00 == "float" || typeof a16 == "float" || typeof a32 == "float" || typeof a48 == "float"){
            throw "Invalid float argument to uint64"
        }

        if (typeof a00 == "string") {
            return fromString(a00, a16)
        }

        if (typeof a00 == "blob" || typeof a00 == "array"){
            if(a00.len() == 4){
                // Assume little endian uint32 blob
                if (a00[0] > 65535 || a00[1] > 65535 || a00[2] > 65535 || a00[3] > 65535) {
                    throw "One of the array/blob values is too big!"
                }

                this._a48 = a00[0].tointeger()
                this._a32 = a00[1].tointeger()
                this._a16 = a00[2].tointeger()
                this._a00 = a00[3].tointeger()
            } else if(a00.len() == 8){
                // Assume little endian uint64 blob
                if (a00[0] > 255 || a00[1] > 255 || a00[2] > 255 || a00[3] > 255 || a00[4] > 255 || a00[5] > 255 || a00[6] > 255 || a00[7] > 255) {
                    throw "One of the array/blob values is too big!"
                }

                this._a48 = a00[0] << 8 | a00[1] & 0xFF
                this._a32 = a00[2] << 8 | a00[3] & 0xFF
                this._a16 = a00[4] << 8 | a00[5] & 0xFF
                this._a00 = a00[6] << 8 | a00[7] & 0xFF
            }
            return this
        }

        if (a16 == null) {
            return fromNumber(a00)
        }

        if (a32 == null) {
            this._a00 = a00 & 0xFFFF
            this._a16 = a00 >>> 16
            this._a32 = a16 & 0xFFFF
            this._a48 = a16 >>> 16
            return this
        }

        return this
    }

    function remainder(){
        if(this._remainder == null) {
            return uint64(0);
        }

        return _remainder
    }

 	/**
 	 * Set the current uint64 from a 32-bit signed number
 	 * @method fromNumber
 	 * @param {Number} number
 	 * @return ThisExpression
 	 */
 	function fromNumber (value) {
        if (typeof value != "integer") {
            throw "Input must be an integer, received \""+(typeof value)+"\"";
        }

        this._a00 = value & 0xFFFF
        this._a16 = value >>> 16
        this._a32 = 0
        this._a48 = 0

        this._string = value.tostring();
        return this;
 	}

    function min(...) {
        local min = vargv[0];
    
        foreach (m in vargv){
            if (min > m){
                min = m;
            }
        }
    
        return min;
    }
 	/**
 	 * Set the current uint64 from a string
 	 * @method fromString
 	 * @param {String} integer as a string
 	 * @return ThisExpression
 	 */
 	function fromString (s, radix=10) {
        if (s.find(".") != null) {
            throw "Error only integers are supported, \""+s+"\" is considered a float due to the \".\""
        }

        this._a00 = 0
 		this._a16 = 0
 		this._a32 = 0
 		this._a48 = 0

 		/*
 			In Javascript, bitwise operators only operate on the first 32 bits
 			of a number, even though parseInt() encodes numbers with a 53 bits
 			mantissa.
 			Therefore uint64(<Number>) can only work on 32 bits.
 			The radix maximum value is 36 (as per ECMA specs) (26 letters + 10 digits)
 			maximum input value is m = 32bits as 1 = 2^32 - 1
 			So the maximum substring length n is:
 			36^(n+1) - 1 = 2^32 - 1
 			36^(n+1) = 2^32
 			(n+1)ln(36) = 32ln(2)
 			n = 32ln(2)/ln(36) - 1
 			n = 5.189644915687692
 			n = 5
 		 */

        local tenTo5 = uint64();
        tenTo5._a00 = 0x86A0;
        tenTo5._a16 = 0x0001;

        local that = clone(this)
        for (local i = 0, len = s.len(); i < len; i += 5) {
            local size = min(5, len - i)
            local value = s.slice(i, i + size).tointeger()
            that = that.multiply(size < 5 ? uint64(math.pow(10, size).tointeger()) : tenTo5).add(value)
        }

        this._a00 = that._a00
        this._a16 = that._a16
        this._a32 = that._a32
        this._a48 = that._a48
        this._string = s;

        return this
 	}

 	/**
 	 * Convert this uint64 to a number (last 32 bits are dropped)
 	 * @method toNumber
 	 * @return {Number} the converted uint64
 	 */
 	function toNumber() {
 		return (this._a16 << 16) | this._a00
 	}

    //NOTE: This is VERY expensive and slow but we won't get to these numbers before imp has a native uint64 implementation
    //      We have a gap in the else branch (base10 quick createString implementation) between the "_largestQuickStringNumber" and the actual maximum uint64 number
    function createStringOld() {
        local radixUint = uint64(10)

        // This stays to prevent tricky logic later when given a number like 2.  Otherwise it gets padded to 02.
        if ( !this.gt_u64(radixUint) ) return this.toNumber().tostring()

        local self = clone(this)
        local res = array(64)
        local i;
        for (i = 63; i >= 0; i--) {
            self = self.div(radixUint)
            res[i] = self._remainder.toNumber().tostring()
            if ( !self.gt_u64(radixUint) ) break
        }
        res[i-1] = self.toNumber().tostring()

        // turn in to a for loop
        return res.reduce(function(previousValue, currentValue){
            if(previousValue == null && currentValue == null)
                return ""
            if(currentValue == null)
                return ""
            return (previousValue.tostring() + currentValue.tostring());
        })
    }

  /**
 	 * Convert this uint64 to a string
 	 * @method createString
 	 * @param {Number} radix (optional, default=10)
 	 * @return {String} the converted uint64
 	 */
    function createString() {
        local cloned = uint64(this);

        //NOTE: This is VERY expensive and slow but we won't get to these numbers before imp has a native uint64 implementation
        //      We have a gap in the else branch (base10 quick createString implementation) between the "_largestQuickStringNumber" and the actual maximum uint64 number
        if(cloned.gt_u64(uint64._largestQuickStringNumber[0])){
            return createStringOld();
        } else {
            local str = "";
            local exp = 18;

            while (exp >= 0) {
                local mul = 1;

                while (mul < 10 && cloned.gte_u64(_createStringValues[exp][mul])) {
                    mul++;
                }
                mul--;

                if (mul > 0 || str != "") {
                    str = str+mul;
                }

                cloned = cloned.sub(_createStringValues[exp][mul]);
                exp--;
            }

            if(str == ""){
                str = "0"
            }

            return str;
        }
    }

 	/**
 	 * Returns the string representation of the uint64
 	 * @method toString
 	 * @return {String} the converted uint64
 	 */
 	function toString() {
        if (this._string == null) {
            this._string = this.createString();
        }

        return this._string;
 	}

 	/**
 	 * Add two uint64. The current uint64 stores the result
 	 * @method add
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function add(other) {
 		other = uint64(other);                  // Work of a clone so that things are nice and immutable
                                                // (and numbers assigned to temporary variables behave like
                                                // a sane person would expect at the cost of performance/RAM)
 		local a00 = this._a00 + other._a00

 		local a16 = a00 >>> 16
 		a16 += this._a16 + other._a16

 		local a32 = a16 >>> 16
 		a32 += this._a32 + other._a32

 		local a48 = a32 >>> 16
 		a48 += this._a48 + other._a48

 		other._a00 = a00 & 0xFFFF
 		other._a16 = a16 & 0xFFFF
 		other._a32 = a32 & 0xFFFF
 		other._a48 = a48 & 0xFFFF

        other._string = null;

 		return other
 	}

 	/**
 	 * Subtract two uint64. The current uint64 stores the result
 	 * @method subtract
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function subtract(other) {
        // Don't need to worry about any cloning / being
        // immutable here, these functions make the necessary copies
        return this.add( uint64(other).negate());
 	}

 	/**
 	 * Multiply two uint64. The current uint64 stores the result
 	 * @method multiply
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function multiply(other) {
 		/*
 			a = a00 + a16 + a32 + a48
 			b = b00 + b16 + b32 + b48
 			a*b = (a00 + a16 + a32 + a48)(b00 + b16 + b32 + b48)
 				= a00b00 + a00b16 + a00b32 + a00b48
 				+ a16b00 + a16b16 + a16b32 + a16b48
 				+ a32b00 + a32b16 + a32b32 + a32b48
 				+ a48b00 + a48b16 + a48b32 + a48b48
 			a16b48, a32b32, a48b16, a48b32 and a48b48 overflow the 64 bits
 			so it comes down to:
 			a*b	= a00b00 + a00b16 + a00b32 + a00b48
 				+ a16b00 + a16b16 + a16b32
 				+ a32b00 + a32b16
 				+ a48b00
 				= a00b00
 				+ a00b16 + a16b00
 				+ a00b32 + a16b16 + a32b00
 				+ a00b48 + a16b32 + a32b16 + a48b00
 		 */
 		other = uint64(other)

 		local a00 = this._a00
 		local a16 = this._a16
 		local a32 = this._a32
 		local a48 = this._a48
 		local b00 = other._a00
 		local b16 = other._a16
 		local b32 = other._a32
 		local b48 = other._a48

 		local c00 = a00 * b00

 		local c16 = c00 >>> 16
 		c16 += a00 * b16
 		local c32 = c16 >>> 16
 		c16 = c16 & 0xFFFF
 		c16 += a16 * b00

 		c32 += c16 >>> 16
 		c32 += a00 * b32
 		local c48 = c32 >>> 16
 		c32 = c32 & 0xFFFF
 		c32 += a16 * b16
 		c48 += c32 >>> 16
 		c32 = c32 & 0xFFFF
 		c32 += a32 * b00

 		c48 += c32 >>> 16
 		c48 += a00 * b48
 		c48 = c48 & 0xFFFF
 		c48 += a16 * b32
 		c48 = c48 & 0xFFFF
 		c48 += a32 * b16
 		c48 = c48 & 0xFFFF
 		c48 += a48 * b00

 		other._a00 = c00 & 0xFFFF
 		other._a16 = c16 & 0xFFFF
 		other._a32 = c32 & 0xFFFF
 		other._a48 = c48 & 0xFFFF

        other._string = null;

 		return other
 	}

 	/**
 	 * Divide two uint64. The current uint64 stores the result.
 	 * The _remainder is made available as the __remainder_ property on
 	 * the uint64. It can be null, meaning there are no _remainder.
 	 * @method div
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function div(other) {
 		other = uint64(other)
 		if ( (other._a16 == 0) && (other._a32 == 0) && (other._a48 == 0) ) {
 			if (other._a00 == 0) throw Error("division by zero")

 			// other == 1, return this
 			if (other._a00 == 1) {
 				this._remainder = null
 				return this
 			}
 		}

 		// other > this: 0
 		if ( other.gt(this) ) {
 			other._remainder = clone(this)
 			other._a00 = 0
 			other._a16 = 0
 			other._a32 = 0
 			other._a48 = 0
            other._string = "0"
 			return other
 		}

 		// other == this: 1
 		if ( this.eq(other) ) {
 			other._remainder = null
 			other._a00 = 1
 			other._a16 = 0
 			other._a32 = 0
 			other._a48 = 0
            other._string = "1";
 			return other
 		}

 		// Shift the divisor left until it is higher than the dividend
 		local i = -1
 		while ( !this.lt(other) ) {
 			// High bit can overflow the default 16bits
 			// Its ok since we right shift after this loop
 			// The overflown bit must be kept though
 			other = other.shiftLeft(1, true)
 			i++
 		}

 		// Set the _remainder
 		local remainder = clone(this)
 		// Initialize the current result to 0
 		local a00 = 0
 		local a16 = 0
 		local a32 = 0
 		local a48 = 0

 		for (; i >= 0; i--) {
 			other = other.shiftRight(1)
 			// If shifted divisor is smaller than the dividend
 			// then subtract it from the dividend
 			if ( !remainder.lt(other) ) {
 				remainder = remainder.subtract(other)

 				// Update the current result
 				if (i >= 48) {
 					a48 = a48 | (1 << (i - 48))
 				} else if (i >= 32) {
 					a32 = a32 | (1 << (i - 32))
 				} else if (i >= 16) {
 					a16 = a16 | (1 << (i - 16))
 				} else {
 					a00 = a00 | (1 << i)
 				}
 			}
 		}

        other._remainder = remainder
        other._a00 = a00
        other._a16 = a16
        other._a32 = a32
        other._a48 = a48

        other._string = null;

 		return other
 	}

 	/**
 	 * Negate the current uint64
 	 * @method negate
 	 * @return ThisExpression
 	 */
 	function negate() {
		local cloned = uint64(this);
 		local v = ( ~cloned._a00 & 0xFFFF ) + 1
 		cloned._a00 = v & 0xFFFF
 		v = (~cloned._a16 & 0xFFFF) + (v >>> 16)
 		cloned._a16 = v & 0xFFFF
 		v = (~cloned._a32 & 0xFFFF) + (v >>> 16)
 		cloned._a32 = v & 0xFFFF
 		cloned._a48 = (~cloned._a48 + (v >>> 16)) & 0xFFFF
        cloned._string = null;

 		return cloned
 	}

 	/**
 	 * @method eq
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function eq(other) {
        other = uint64(other)
 		return (this._a48 == other._a48) && (this._a00 == other._a00)
 			 && (this._a32 == other._a32) && (this._a16 == other._a16)
 	}

 	/**
 	 * Greater than (strict)
 	 * @method gt
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function gt(other) {
        other = uint64(other)
 		if (this._a48 > other._a48) return true
 		if (this._a48 < other._a48) return false
 		if (this._a32 > other._a32) return true
 		if (this._a32 < other._a32) return false
 		if (this._a16 > other._a16) return true
 		if (this._a16 < other._a16) return false
 		return this._a00 > other._a00
 	}

 	/**
 	 * Less than (strict)
 	 * @method lt
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function lt(other) {
        other = uint64(other)
 		if (this._a48 < other._a48) return true
 		if (this._a48 > other._a48) return false
 		if (this._a32 < other._a32) return true
 		if (this._a32 > other._a32) return false
 		if (this._a16 < other._a16) return true
 		if (this._a16 > other._a16) return false
 		return this._a00 < other._a00
 	}

 	function lte(other) {
 		return this.eq(other) || this.lt(other)
 	}

 	function gte(other) {
 		return this.eq(other) || this.gt(other)
 	}

 	/**
 	 * @method eq
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function eq_u64(other) {
 		return (this._a48 == other._a48) && (this._a00 == other._a00)
 			 && (this._a32 == other._a32) && (this._a16 == other._a16)
 	}

 	/**
 	 * Greater than (strict)
 	 * @method gt
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function gt_u64(other) {
 		if (this._a48 > other._a48) return true
 		if (this._a48 < other._a48) return false
 		if (this._a32 > other._a32) return true
 		if (this._a32 < other._a32) return false
 		if (this._a16 > other._a16) return true
 		if (this._a16 < other._a16) return false
 		return this._a00 > other._a00
 	}

 	/**
 	 * Less than (strict)
 	 * @method lt
 	 * @param {Object} other uint64
 	 * @return {Boolean}
 	 */
 	function lt_u64(other) {
 		if (this._a48 < other._a48) return true
 		if (this._a48 > other._a48) return false
 		if (this._a32 < other._a32) return true
 		if (this._a32 > other._a32) return false
 		if (this._a16 < other._a16) return true
 		if (this._a16 > other._a16) return false
 		return this._a00 < other._a00
 	}

 	function lte_u64(other) {
 		return this.eq_u64(other) || this.lt_u64(other)
 	}

 	function gte_u64(other) {
 		return this.eq_u64(other) || this.gt_u64(other)
 	}

 	/**
 	 * Bitwise OR
 	 * @method or
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function or(other) {
 		other = uint64(other)
 		other._a00 = this._a00 | other._a00
 		other._a16 = this._a16 | other._a16
 		other._a32 = this._a32 | other._a32
 		other._a48 = this._a48 | other._a48
        other._string = null;

 		return other
 	}

 	/**
 	 * Bitwise AND
 	 * @method and
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function and(other) {
 		other = uint64(other)
 		other._a00 = this._a00 & other._a00
 		other._a16 = this._a16 & other._a16
 		other._a32 = this._a32 & other._a32
 		other._a48 = this._a48 & other._a48
        other._string = null;

 		return other
 	}

 	/**
 	 * Bitwise XOR
 	 * @method xor
 	 * @param {Object} other uint64
 	 * @return ThisExpression
 	 */
 	function xor(other) {
 		other = uint64(other)
 		other._a00 = this._a00 ^ other._a00
 		other._a16 = this._a16 ^ other._a16
 		other._a32 = this._a32 ^ other._a32
 		other._a48 = this._a48 ^ other._a48
        other._string = null;

 		return other
 	}

 	/**
 	 * Bitwise NOT
 	 * @method not
 	 * @return ThisExpression
 	 */
 	function not() {
        local cloned = clone(this)
 		cloned._a00 = ~this._a00 & 0xFFFF
 		cloned._a16 = ~this._a16 & 0xFFFF
 		cloned._a32 = ~this._a32 & 0xFFFF
 		cloned._a48 = ~this._a48 & 0xFFFF
        cloned._string = null;

 		return cloned
 	}

 	/**
 	 * Bitwise shift right
 	 * @method shiftRight
 	 * @param {Number} number of bits to shift
 	 * @return ThisExpression
 	 */
 	function shiftRight(n) {
        local cloned = clone(this)
 		n %= 64
 		if (n >= 48) {
 			cloned._a00 = cloned._a48 >> (n - 48)
 			cloned._a16 = 0
 			cloned._a32 = 0
 			cloned._a48 = 0
 		} else if (n >= 32) {
 			n -= 32
 			cloned._a00 = ( (cloned._a32 >> n) | (cloned._a48 << (16-n)) ) & 0xFFFF
 			cloned._a16 = (cloned._a48 >> n) & 0xFFFF
 			cloned._a32 = 0
 			cloned._a48 = 0
 		} else if (n >= 16) {
 			n -= 16
 			cloned._a00 = ( (cloned._a16 >> n) | (cloned._a32 << (16-n)) ) & 0xFFFF
 			cloned._a16 = ( (cloned._a32 >> n) | (cloned._a48 << (16-n)) ) & 0xFFFF
 			cloned._a32 = (cloned._a48 >> n) & 0xFFFF
 			cloned._a48 = 0
 		} else {
 			cloned._a00 = ( (cloned._a00 >> n) | (cloned._a16 << (16-n)) ) & 0xFFFF
 			cloned._a16 = ( (cloned._a16 >> n) | (cloned._a32 << (16-n)) ) & 0xFFFF
 			cloned._a32 = ( (cloned._a32 >> n) | (cloned._a48 << (16-n)) ) & 0xFFFF
 			cloned._a48 = (cloned._a48 >> n) & 0xFFFF
 		}

        cloned._string = null;

 		return cloned
 	}

 	/**
 	 * Bitwise shift left
 	 * @method shiftLeft
 	 * @param {Number} number of bits to shift
 	 * @param {Boolean} allow overflow
 	 * @return ThisExpression
 	 */
 	function shiftLeft(n, allowOverflow) {
        local cloned = clone(this)
        n %= 64

     	if (n >= 48) {
 			cloned._a48 = cloned._a00 << (n - 48)
 			cloned._a32 = 0
 			cloned._a16 = 0
 			cloned._a00 = 0
 		} else if (n >= 32) {
 			n -= 32
 			cloned._a48 = (cloned._a16 << n) | (cloned._a00 >> (16-n))
 			cloned._a32 = (cloned._a00 << n) & 0xFFFF
 			cloned._a16 = 0
 			cloned._a00 = 0
 		} else if (n >= 16) {
 			n -= 16
 			cloned._a48 = (cloned._a32 << n) | (cloned._a16 >> (16-n))
 			cloned._a32 = ( (cloned._a16 << n) | (cloned._a00 >> (16-n)) ) & 0xFFFF
 			cloned._a16 = (cloned._a00 << n) & 0xFFFF
 			cloned._a00 = 0
 		} else {
 			cloned._a48 = (cloned._a48 << n) | (cloned._a32 >> (16-n))
 			cloned._a32 = ( (cloned._a32 << n) | (cloned._a16 >> (16-n)) ) & 0xFFFF
 			cloned._a16 = ( (cloned._a16 << n) | (cloned._a00 >> (16-n)) ) & 0xFFFF
 			cloned._a00 = (cloned._a00 << n) & 0xFFFF
 		}

 		if (!allowOverflow) {
             cloned._a48 = cloned._a48 & 0xFFFF
 		}

        cloned._string = null;

 		return cloned
 	}

 	/**
 	 * Bitwise rotate left
 	 * @method rotl
 	 * @param {Number} number of bits to rotate
 	 * @return ThisExpression
 	 */
 	function rotl(n) {
 		n %= 64
 		if (n == 0) return this

        local cloned = clone(this)
        if (n >= 32) {
            // A.B.C.D
            // B.C.D.A rotl(16)
            // C.D.A.B rotl(32)
            local v = cloned._a00
            cloned._a00 = cloned._a32
            cloned._a32 = v
            v = cloned._a48
            cloned._a48 = cloned._a16
            cloned._a16 = v
            if (n == 32) return cloned
            n -= 32
        }

 		local high = (cloned._a48 << 16) | cloned._a32
 		local low = (cloned._a16 << 16) | cloned._a00

 		local _high = (high << n) | (low >>> (32 - n))
 		local _low = (low << n) | (high >>> (32 - n))

 		cloned._a00 = _low & 0xFFFF
 		cloned._a16 = _low >>> 16
 		cloned._a32 = _high & 0xFFFF
 		cloned._a48 = _high >>> 16

        cloned._string = null;

 		return cloned
 	}

 	/**
 	 * Bitwise rotate right
 	 * @method rotr
 	 * @param {Number} number of bits to rotate
 	 * @return ThisExpression
 	 */
 	function rotr(n) {
 		n %= 64
 		if (n == 0) return this

        local cloned = clone(this)
 		if (n >= 32) {
 			// A.B.C.D
 			// D.A.B.C rotr(16)
 			// C.D.A.B rotr(32)
 			local v = cloned._a00
 			cloned._a00 = cloned._a32
 			cloned._a32 = v
 			v = cloned._a48
 			cloned._a48 = cloned._a16
 			cloned._a16 = v
 			if (n == 32) return cloned
 			n -= 32
 		}

 		local high = (cloned._a48 << 16) | cloned._a32
 		local low = (cloned._a16 << 16) | cloned._a00

 		local _high = (high >>> n) | (low << (32 - n))
 		local _low = (low >>> n) | (high << (32 - n))

 		cloned._a00 = _low & 0xFFFF
 		cloned._a16 = _low >>> 16
 		cloned._a32 = _high & 0xFFFF
 		cloned._a48 = _high >>> 16

        cloned._string = null;

 		return cloned
 	}

    /**
     * Overflown
     * @method isOverflown
     * @param {this} uint64 to check for overflow on
     * @return bool
     */
    function isOverflown() {
        local _a48 = this._a48
        _a48 = _a48 >> 16;

        // If the upper bits have data, there is overflow
        if (_a48 != 0) {
            return true;
        }
        return false;
    }

 	/**
 	 * Used with JSONEncoder.encode to allow for properly JSONizing big numbers
 	 * @method _serialize
 	 * @return {[type]}   [description]
 	 */
 	 function _serializeRaw(){
 		 return this.toString();
 	 }

    function _tostring(){
        return format("%.4X %.4X %.4X %.4X - r=%d", this._a00, this._a16, this._a32 ,this._a48, this.remainder().toNumber())
    }
 }

uint64._initCreateStringValues();

disconnectionManager <- {

    // ********** Public Properties **********

    "reconnectTimeout" : 30,
    "reconnectDelay" : 60,
    "monitoring" : false,
    "isConnected" : true,
    "message" : "",
    "reason" : SERVER_CONNECTED,
    "retries" : 0,
    "offtime" : null,
    "eventCallback" : null,

    /**
     * Begin monitoring device connection state
     *
     * @param {integer/float} [timeout]    - The max. time (in seconds) allowed for the server to acknowledge receipt of data. Default: 10s
     * @param {integer}       [sendPolicy] - The send policy: either WAIT_TIL_SENT or WAIT_FOR_ACK. Default: WAIT_TIL_SENT
     *
     */
    "start" : function(timeout = 10, sendPolicy = WAIT_TIL_SENT) {
        // Check parameter type, and fix if it's wrong
        if (typeof timeout != "integer" && typeof timeout != "float") timeout = 10;
        if (sendPolicy != WAIT_TIL_SENT && sendPolicy != WAIT_FOR_ACK) sendPolicy = WAIT_TIL_SENT;

        // Register handlers etc.
        // NOTE We assume use of RETURN_ON_ERROR as DisconnectionManager is
        //      largely redundant with the SUSPEND_ON_ERROR policy
        server.setsendtimeoutpolicy(RETURN_ON_ERROR, sendPolicy, timeout);
        server.onunexpecteddisconnect(disconnectionManager._hasDisconnected.bindenv(this));
        disconnectionManager.monitoring = true;
        disconnectionManager._wakeup({"message": "Enabling disconnection monitoring"});

        // Check for initial connection (give it time to connect)
        disconnectionManager.connect();
    },

    /**
     * Stop monitoring connection state
     *
     */
    "stop" : function() {
        // De-Register handlers etc.
        disconnectionManager.monitoring = false;
        disconnectionManager._wakeup({"message": "Disabling disconnection monitoring"});
    },

    /**
     * Attempt to connect to the server. No effect if the imp is already connected
     *
     */
    "connect" : function() {
        // Attempt to connect to the server if we're not connected already
        // We do this to set our initial state
        disconnectionManager.isConnected = server.isconnected();
        if (!disconnectionManager.isConnected) {
            disconnectionManager._wakeup({"message": "Manually connecting to server", "type": "connecting"});
            server.connect(disconnectionManager._eventHandler.bindenv(this), disconnectionManager.reconnectTimeout);
        } else {
            disconnectionManager._wakeup({"type": "connected"});
        }
    },

    /**
     * Manually disconnect from the server
     *
     */
    "disconnect" : function() {
        // Disconnect from the server if we're not disconnected already
        disconnectionManager.isConnected = false;
        if (server.isconnected()) {
            imp.onidle(function() {
                server.flush(10);
                server.disconnect();
                disconnectionManager._wakeup({"message": "Manually disconnected from server", "type": "disconnected"});
            }.bindenv(this));
        } else {
            disconnectionManager._wakeup({"type": "disconnected"});
        }
    },

    /**
     * Connection/disconnection event descriptor
     *
     * @typedef {table} eventDesc
     *
     * @property {string}  type    - Human-readable event type: "connected", "connecting", "disconnected"
     * @property {string}  message - Human-readable notification message
     * @property {integer} ts      - The timestamp when the message was queued. Added automatically
     *
     */

    /**
     * Connection state change notification callback function
     *
     * @callback eventcallback
     *
     * @param {eventDesc} event - An event descriptior
     *
     */

    /**
     * Set the manager's network event callback
     *
     * @param {eventcallback} cb - A function to which connection state change notifications are sent
     *
     */
    "setCallback" : function(cb = null) {
        // Convenience function for setting the framework's event report callback
        if (cb != null && typeof cb == "function") disconnectionManager.eventCallback = cb;
    },

    // ********** Private Properties DO NOT ACCESS DIRECTLY **********

    "_noIP" : false,
    "_codes" : ["No WiFi connection", "No LAN connection", "No IP address (DHCP error)", "impCloud IP not resolved (DNS error)",
                "impCloud unreachable", "Connected to impCloud", "No proxy server", "Proxy credentials rejected"],

    // ********** Private Methods DO NOT CALL DIRECTLY **********

    /**
     * Function called whenever the server connection is broken or re-established, initially by impOS' unexpected disconnect
     * code and then repeatedly by server.connect(), below, as it periodically attempts to reconnect
     *
     * @private
     *
     * @param {integer} reason - The imp API (see server.connect()) connection/disconnection event code
     *
     */
    "_eventHandler" : function(reason) {
        // If we are not checking for unexpected disconnections, bail
        if (!disconnectionManager.monitoring) return;

        if (reason != SERVER_CONNECTED) {
            // The device wasn't previously disconnected, so set the state to 'disconnected', ie. 'isConnected' is true
            if (disconnectionManager.isConnected) {
                // Set the connection state data and disconnection info data
                // NOTE connection fails 60s before 'eventHandler' is called
                disconnectionManager.isConnected = false;
                disconnectionManager.retries = 0;
                disconnectionManager.reason = reason;
                disconnectionManager.offtime = date();

                // Send a 'disconnected' event to the host app
                disconnectionManager._wakeup({"message": "Device unexpectedly disconnected", "type" : "disconnected"});
            } else {
                // Send a 'still disconnected' event to the host app
                local m = disconnectionManager._formatTimeString();
                disconnectionManager._wakeup({"message": "Device still disconnected at " + m,
                                              "type" : "disconnected"});
            }

            // Schedule an attempt to re-connect in 'reconnectDelay' seconds
            imp.wakeup(disconnectionManager.reconnectDelay, function() {
                if (!server.isconnected()) {
                    // If we're not connected, send a 'connecting' event to the host app and try to connect
                    disconnectionManager.retries += 1;
                    disconnectionManager._wakeup({"message": "Device connecting", "type" : "connecting"});
                    server.connect(disconnectionManager._eventHandler.bindenv(this), disconnectionManager.reconnectTimeout);
                } else {
                    // If we are connected, re-call 'eventHandler()' to make sure the 'connnected' flow is executed
                    // disconnectionManager._wakeup({"message": "Wakeup code called, but device already connected"});
                    disconnectionManager._eventHandler(SERVER_CONNECTED);
                }
            }.bindenv(this));
        } else {
            // The imp is back online
            if (!disconnectionManager.isConnected) {
                // Send a 'connected' event to the host app
                // Report the time that the device went offline
                local m = disconnectionManager._formatTimeString(disconnectionManager.offtime);
                m = format("Went offline at %s. Reason: %s (%i)", m, disconnectionManager._getReason(disconnectionManager.reason), disconnectionManager.reason);
                disconnectionManager._wakeup({"message": m});

                // Report the time that the device is back online
                m = disconnectionManager._formatTimeString();
                m = format("Back online at %s. Connection attempts: %i", m, disconnectionManager.retries);
                disconnectionManager._wakeup({"message": m, "type" : "connected"});
            }

            // Re-set state data
            disconnectionManager.isConnected = true;
            disconnectionManager._noIP = false;
            disconnectionManager.offtime = null;
        }
    },

    /**
     * This is an intercept function for 'server.onunexpecteddisconnect()' to handle the double-calling of this method's registered handler
     * when the imp loses its link to DHCP but still has WiFi
     *
     * @private
     *
     * @param {integer} reason - The imp API (see server.connect()) connection/disconnection event code
     *
     */
    "_hasDisconnected" : function(reason) {
        if (!disconnectionManager._noIP) {
            disconnectionManager._noIP = true;
            disconnectionManager._eventHandler(reason);
        }
    },

    /**
     * Return the connection error/disconnection reason as a human-readable string
     *
     * @private
     *
     * @param {integer} code - The imp API (see server.connect()) connection/disconnection event code
     *
     * @returns {string} The human-readable string
     *
     */
    "_getReason" : function(code) {
        return _codes[code];
    },

    /**
     * Format a timestamp string, either the current time (default; pass null as the argument),
     * or a specific time (pass a timestamp as the argument). Includes the timezone
     * NOTE It is able to make use of the 'utilities' BST checker, if also included in your application
     *
     * @private
     *
     * @param {table} [n] - A Squirrel date/time description table (see date()). Default: current date
     *
     * @returns {string} The timestamp string, eg. "12:45:0 +1:00"
     *
     */
    "_formatTimeString" : function(time = null) {
        local bst = false;
        if ("utilities" in getroottable()) bst = utilities.isBST();
        if (time == null) time = date();
        time.hour += (bst ? 1 : 0);
        if (time.hour > 23) time.hour -= 24;
        local z = bst ? "+01:00" : "UTC";
        return format("%02i:%02i:%02i %s", time.hour, time.min, time.sec, z);
    },

    //
    /**
     * Queue up a message post with the supplied data on an immediate timer
     *
     * @private
     *
     * @param {eventDesc} evd - An event descriptor
     *
     */
    "_wakeup": function(evd) {
        // Add a message timestamp
        evd.ts <- time();

        if (disconnectionManager.eventCallback != null) {
            imp.wakeup(0, function() {
                disconnectionManager.eventCallback(evd);
            });
        }
    }
}

stpmclass <- {
    "connected" : false,
    "CRC_8" : 0x07,
    "CRC_u8Checksum" : 0,
    "stpmuart" : null,
    "pblob" : blob(5),
    "FACTOR_POWER_ON_ENERGY" : 858,
    "defultconfig" : 0x16,
	"defultdata1" : [ 0x040000a0,
					0x240000a0,
					0x000004e0,
					0x00000000,
					0x003ff800,
					0x003ff800,
					0x003ff800,
					0x003ff800,
					0x00000fff,
					0x00000fff,
					0x00000fff,
					0x00000fff,
					0x03270327,
					0x03270327,
					0x00000000,
					0x00000000,
					0x00000000,
					0x00000000,
					0x00004007],
	"defaultpowerFact": [30154605,30154605],
	"defaultenergyFact": [30154605,30154605], // energy is power divided by 858
	"defaultvoltageFact": [116274,116274],
	"defaultcurrentFact":[25934,25934],
	"metroData" : {},
	"STPMADDRESS":{},
	"stpmregs":{},
	"_tableinit" : function() {
        metroData.nbPhase <- 0;
		metroData.powerActive <- 0;
		metroData.powerReactive <- 0;
		metroData.powerApparent <- 0;
		metroData.energyActive <- 0;
		metroData.energyReactive <- 0;
		metroData.energyApparent <- 0;
		metroData.rmsvoltage <- 0;
		metroData.rmscurrent <- 0;
		
			   STPMADDRESS.STPM_DSPCTRL1  <- 0x00;
			   STPMADDRESS.STPM_DSPCTRL2  <- 0x02;
			   STPMADDRESS.STPM_DSPCTRL3  <- 0x04;
			   STPMADDRESS.STPM_DSPCTRL4  <- 0x06;
			   STPMADDRESS.STPM_DSPCTRL5  <- 0x08;
			   STPMADDRESS.STPM_DSPCTRL6  <- 0x0A;
			   STPMADDRESS.STPM_DSPCTRL7  <- 0x0C;
			   STPMADDRESS.STPM_DSPCTRL8  <- 0x0E;
			   STPMADDRESS.STPM_DSPCTRL9  <- 0x10;
			   STPMADDRESS.STPM_DSPCTRL10 <- 0x12;
			   STPMADDRESS.STPM_DSPCTRL11 <- 0x14;
			   STPMADDRESS.STPM_DSPCTRL12 <- 0x16;
			   STPMADDRESS.STPM_DFECTRL1  <- 0x18;
			   STPMADDRESS.STPM_DFECTRL2  <- 0x1A;
			   STPMADDRESS.STPM_DSPIRQ1   <- 0x1C;
			   STPMADDRESS.STPM_DSPIRQ2   <- 0x1E;
			   STPMADDRESS.STPM_DSPSR1    <- 0x20;
			   STPMADDRESS.STPM_DSPSR2    <- 0x22;
			   STPMADDRESS.STPM_USREG1    <- 0x24;
			   STPMADDRESS.STPM_USREG2    <- 0x26;
			   STPMADDRESS.STPM_USREG3    <- 0x28;
			   STPMADDRESS.STPM_DSPEVENT1 <- 0x2A;
			   STPMADDRESS.STPM_DSPEVENT2 <- 0x2C;
			   STPMADDRESS.STPM_DSP_REG1  <- 0x2E;
			   STPMADDRESS.STPM_DSP_REG2  <- 0x30;
			   STPMADDRESS.STPM_DSP_REG3  <- 0x32;
			   STPMADDRESS.STPM_DSP_REG4  <- 0x34;
			   STPMADDRESS.STPM_DSP_REG5  <- 0x36;
			   STPMADDRESS.STPM_DSP_REG6  <- 0x38;
			   STPMADDRESS.STPM_DSP_REG7  <- 0x3A;
			   STPMADDRESS.STPM_DSP_REG8  <- 0x3C;
			   STPMADDRESS.STPM_DSP_REG9  <- 0x3E;
			   STPMADDRESS.STPM_DSP_REG10 <- 0x40;
			   STPMADDRESS.STPM_DSP_REG11 <- 0x42;
			   STPMADDRESS.STPM_DSP_REG12 <- 0x44;
			   STPMADDRESS.STPM_DSP_REG13 <- 0x46;
			   STPMADDRESS.STPM_DSP_REG14 <- 0x48;
			   STPMADDRESS.STPM_DSP_REG15 <- 0x4A;
			   STPMADDRESS.STPM_DSP_REG16 <- 0x4C;
			   STPMADDRESS.STPM_DSP_REG17 <- 0x4E;
			   STPMADDRESS.STPM_DSP_REG18 <- 0x50;
			   STPMADDRESS.STPM_DSP_REG19 <- 0x52;
			   STPMADDRESS.STPM_CH1_REG1  <- 0x54;
			   STPMADDRESS.STPM_CH1_REG2  <- 0x56;
			   STPMADDRESS.STPM_CH1_REG3  <- 0x58;
			   STPMADDRESS.STPM_CH1_REG4  <- 0x5A;
			   STPMADDRESS.STPM_CH1_REG5  <- 0x5C;
			   STPMADDRESS.STPM_CH1_REG6  <- 0x5E;
			   STPMADDRESS.STPM_CH1_REG7  <- 0x60;
			   STPMADDRESS.STPM_CH1_REG8  <- 0x62;
			   STPMADDRESS.STPM_CH1_REG9  <- 0x64;
			   STPMADDRESS.STPM_CH1_REG10 <- 0x66;
			   STPMADDRESS.STPM_CH1_REG11 <- 0x68;
			   STPMADDRESS.STPM_CH1_REG12 <- 0x6A;
			   STPMADDRESS.STPM_CH2_REG1  <- 0x6C;
			   STPMADDRESS.STPM_CH2_REG2  <- 0x6E;
			   STPMADDRESS.STPM_CH2_REG3  <- 0x70;
			   STPMADDRESS.STPM_CH2_REG4  <- 0x72;
			   STPMADDRESS.STPM_CH2_REG5  <- 0x74;
			   STPMADDRESS.STPM_CH2_REG6  <- 0x76;
			   STPMADDRESS.STPM_CH2_REG7  <- 0x78;
			   STPMADDRESS.STPM_CH2_REG8  <- 0x7A;
			   STPMADDRESS.STPM_CH2_REG9  <- 0x7C;
			   STPMADDRESS.STPM_CH2_REG10 <- 0x7E;
			   STPMADDRESS.STPM_CH2_REG11 <- 0x80;
			   STPMADDRESS.STPM_CH2_REG12 <- 0x82;
			   STPMADDRESS.STPM_TOT_REG1  <- 0x84;
			   STPMADDRESS.STPM_TOT_REG2  <- 0x86;
			   STPMADDRESS.STPM_TOT_REG3  <- 0x88;
			   STPMADDRESS.STPM_TOT_REG4  <- 0x8A;
			   
			   stpmregs.DSPCTRL1 <- 0;
			   stpmregs.DSPCTRL2 <- 0;
			   stpmregs.DSPCTRL3 <- 0;
			   stpmregs.DSPCTRL4 <- 0;
			   stpmregs.DSPCTRL5 <- 0;
			   stpmregs.DSPCTRL6 <- 0;
			   stpmregs.DSPCTRL7 <- 0;
			   stpmregs.DSPCTRL8 <- 0;
			   stpmregs.DSPCTRL9 <- 0;
			   stpmregs.DSPCTRL10<- 0;
			   stpmregs.DSPCTRL11<- 0;
			   stpmregs.DSPCTRL12<- 0;
			   stpmregs.DFECTRL1 <- 0;
			   stpmregs.DFECTRL2 <- 0;
			   stpmregs.DSPIRQ1  <- 0; 
			   stpmregs.DSPIRQ2  <- 0; 
			   stpmregs.DSPSR1   <- 0;  
			   stpmregs.DSPSR2   <- 0;  
			   stpmregs.UARTSPICR1<-0;
			   stpmregs.UARTSPICR2<-0;
			   stpmregs.UARTSPISR<- 0;
			   stpmregs.DSPEVENT1<- 0;
			   stpmregs.DSPEVENT2<- 0;
			   stpmregs.DSP_REG1 <- 0;
			   stpmregs.DSP_REG2 <- 0;
			   stpmregs.DSP_REG3 <- 0;
			   stpmregs.DSP_REG4 <- 0;
			   stpmregs.DSP_REG5 <- 0;
			   stpmregs.DSP_REG6 <- 0;
			   stpmregs.DSP_REG7 <- 0;
			   stpmregs.DSP_REG8 <- 0;
			   stpmregs.DSP_REG9 <- 0;
			   stpmregs.DSP_REG10<- 0;
			   stpmregs.DSP_REG11<- 0;
			   stpmregs.DSP_REG12<- 0;
			   stpmregs.DSP_REG13<- 0;
			   stpmregs.DSP_REG14<- 0;
			   stpmregs.DSP_REG15<- 0;
			   stpmregs.DSP_REG16<- 0;
			   stpmregs.DSP_REG17<- 0;
			   stpmregs.DSP_REG18<- 0;
			   stpmregs.DSP_REG19<- 0;
			   stpmregs.CH1_REG1 <- 0;
			   stpmregs.CH1_REG2 <- 0;
			   stpmregs.CH1_REG3 <- 0;
			   stpmregs.CH1_REG4 <- 0;
			   stpmregs.CH1_REG5 <- 0;
			   stpmregs.CH1_REG6 <- 0;
			   stpmregs.CH1_REG7 <- 0;
			   stpmregs.CH1_REG8 <- 0;
			   stpmregs.CH1_REG9 <- 0;
			   stpmregs.CH1_REG10<- 0;
			   stpmregs.CH1_REG11<- 0;
			   stpmregs.CH1_REG12<- 0;
			   stpmregs.CH2_REG1 <- 0;
			   stpmregs.CH2_REG2 <- 0;
			   stpmregs.CH2_REG3 <- 0;
			   stpmregs.CH2_REG4 <- 0;
			   stpmregs.CH2_REG5 <- 0;
			   stpmregs.CH2_REG6 <- 0;
			   stpmregs.CH2_REG7 <- 0;
			   stpmregs.CH2_REG8 <- 0;
			   stpmregs.CH2_REG9 <- 0;
			   stpmregs.CH2_REG10<- 0;
			   stpmregs.CH2_REG11<- 0;
			   stpmregs.CH2_REG12<- 0;
			   stpmregs.TOT_REG1 <- 0;
			   stpmregs.TOT_REG2 <- 0;
			   stpmregs.TOT_REG3 <- 0;
			   stpmregs.TOT_REG4 <- 0;
    },				
    "_stpmData" : function(){
        local  b = stpmclass.stpmuart.read();
        local regvalue = b;
        local i=8;
        while (b != -1 ) {
            //server.log("received: " + b);
            b = stpmclass.stpmuart.read();
            regvalue = b<<i | regvalue;
            i = i+8;
        }
        //server.log("register value is " + format("%08X",regvalue));
        return regvalue;
         //local  b = stpmclass.stpmuart.readblob();
         //server.log("received: " + b);
    },
    "_init" : function(){
        stpmclass.stpmuart = hardware.uartDM;
        if(stpmuart == null)
            server.log("Uart error");
        stpmclass.stpmuart.setrxfifosize(128);
        stpmclass.stpmuart.configure(9600, 8, PARITY_NONE, 1, NO_CTSRTS,_stpmData);
    },

    "reverse" : function(in_byte) {
        in_byte = ((in_byte >> 1) & 0x55) | ((in_byte << 1) & 0xaa);
        in_byte = ((in_byte >> 2) & 0x33) | ((in_byte << 2) & 0xcc);
        in_byte = ((in_byte >> 4) & 0x0F) | ((in_byte << 4) & 0xF0);
    
        return in_byte;
    },
    "p1" : function(in_Data){
        local loc_u8Idx;
        local loc_u8Temp;
        loc_u8Idx=0;
        while(loc_u8Idx<8)
        {
            loc_u8Temp = in_Data^CRC_u8Checksum;
            stpmclass.CRC_u8Checksum = stpmclass.CRC_u8Checksum<<1;
            if(loc_u8Temp&0x80)
            {
                stpmclass.CRC_u8Checksum = stpmclass.CRC_u8Checksum ^ stpmclass.CRC_8;
            }
            in_Data = in_Data <<1;
            loc_u8Idx++;
        }
    },
    "p2" : function( pBuf){
        local     i;
        stpmclass.CRC_u8Checksum = 0x00;
       for (i=0; i<4; i++)
        {
            p1(reverse(pBuf[i]));
        }
        return stpmclass.CRC_u8Checksum;
    },
    "readreg" : function(reg){
        pblob[0] = 0xFF & reg;
        pblob[1] = 0xFF;
        pblob[2] = 0xFF;
        pblob[3] = 0xFF;;
        local aa = reverse(stpmclass.p2(pblob));
        pblob[4] = 0xFF & aa;
        //server.log("register address =["+ pblob[0]+"]");
        stpmclass.stpmuart.write(stpmclass.pblob);
        imp.sleep(0.01);
    },
    "writereg" : function(b1,b2,b3,b4){
        pblob[0] = 0xFF & b1;
        pblob[1] = 0xFF & b2;
        pblob[2] = 0xFF & b3;
        pblob[3] = 0xFF & b4;
        local aa = reverse(stpmclass.p2(pblob));
        pblob[4] = 0xFF & aa;
        //server.log(pblob);
        stpmclass.stpmuart.write(stpmclass.pblob);
        imp.sleep(0.01);
    },
    "setspeed" : function(){
        // set to 57600, STPM32
        pblob[0] = 0xFF;
        pblob[1] = 0xFF &  STPMADDRESS.STPM_USREG2;
        pblob[2] = 0xFF & 16;
        pblob[3] = 0xFF & 01;
        local aa = reverse(stpmclass.p2(pblob));
        pblob[4] = 0xFF & aa;
        stpmclass.stpmuart.write(stpmclass.pblob);
        imp.sleep(0.1);
        //set host
        stpmclass.stpmuart.configure(57600, 8, PARITY_NONE, 1, NO_CTSRTS,_stpmData);
    },
    "readblock": function(){
        local i=0;
        readreg(i);
         _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL1 = _stpmData();
        if(stpmregs.DSPCTRL1 != defultdata1){
            server.log("STPM32 is not connected!");
        }  else{
            conencted = true;
            return;
        }
        
        readreg(0xFF);
        stpmregs.DSPCTRL2 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL3 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL4 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL5 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL6 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL7 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL8 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL9 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL10 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL11 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPCTRL12 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DFECTRL1 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DFECTRL2 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPIRQ1 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPIRQ2 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPSR1 = _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPSR2 = _stpmData();
        
        readreg(0xFF);
        stpmregs.UARTSPICR1 = _stpmData();
        
        readreg(0xFF);
        stpmregs.UARTSPICR2 = _stpmData();


        //server.log(format("%08X",stpmregs.DSPCTRL1));
        //server.log(format("%08X",stpmregs.DSPCTRL2));
        server.log(format("%08X",stpmregs.DSPCTRL3));
       // server.log(format("%08X",stpmregs.DSPCTRL4));
       // server.log(format("%08X",stpmregs.DSPCTRL5));
        //server.log(format("%08X",stpmregs.DSPCTRL6));
        //server.log(format("%08X",stpmregs.DSPCTRL7));
        //server.log(format("%08X",stpmregs.DSPCTRL8));
       // server.log(format("%08X",stpmregs.DSPCTRL9));
        //server.log(format("%08X",stpmregs.DSPCTRL10));
        //server.log(format("%08X",stpmregs.DSPCTRL11));
        //server.log(format("%08X",stpmregs.DSPCTRL12));
        //server.log(format("%08X",stpmregs.DFECTRL1 ));
        //server.log(format("%08X",stpmregs.DFECTRL2 ));
        //server.log(format("%08X",stpmregs.DSPIRQ1  ));
        //server.log(format("%08X",stpmregs.DSPIRQ2  ));
       // server.log(format("%08X",stpmregs.DSPSR1   ));
        //server.log(format("%08X",stpmregs.DSPSR2   ));
       // server.log(format("%08X",stpmregs.UARTSPICR1));
        server.log(format("%08X",stpmregs.UARTSPICR2));
    },
    
    "autolatch": function(){
        readreg(STPMADDRESS.STPM_DSPCTRL3);
        _stpmData();
        readreg(0xFF);
        stpmregs.DSPCTRL3 = _stpmData();
        
        stpmregs.DSPCTRL3 = stpmregs.DSPCTRL3 & ~0x00200000;
        stpmregs.DSPCTRL3 = stpmregs.DSPCTRL3 & ~0x00400000;
        stpmregs.DSPCTRL3 = stpmregs.DSPCTRL3 | 0x00800000;
        local b1 = (stpmregs.DSPCTRL3 >>16) & 0xFF;
        local b2 = (stpmregs.DSPCTRL3 >>24) & 0xFF;
        local b3 = (stpmregs.DSPCTRL3) & 0xFF;
        local b4 = (stpmregs.DSPCTRL3 >>8) & 0xFF;
        
        writereg(0xFF, STPMADDRESS.STPM_DSPCTRL3, b3,b4);
        writereg(0xFF, STPMADDRESS.STPM_DSPCTRL3+1, b1,b2);
    },
    "swlatch" : function(){
        
    },
    "getmeasure" : function(){
        // read 33 bytes from STPM_DSPEVENT1
        readreg(STPMADDRESS.STPM_DSPEVENT1);
        _stpmData();
        
        readreg(0xFF);
        stpmregs.DSPEVENT1 = _stpmData();
        readreg(0xFF);
        stpmregs.DSPEVENT2 = _stpmData();
        readreg(0xFF);
        stpmregs.DSP_REG1 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG2 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG3 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG4 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG5 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG6 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG7 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG8 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG9 = _stpmData();    
        readreg(0xFF);
        stpmregs.DSP_REG10 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG11 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG12 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG13 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG14 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG15 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG16 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG17 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG18 = _stpmData();   
        readreg(0xFF);
        stpmregs.DSP_REG19 = _stpmData();   
        readreg(0xFF);
        stpmregs.CH1_REG1 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG2 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG3 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG4 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG5 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG6 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG7 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG8 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG9 = _stpmData();    
        readreg(0xFF);
        stpmregs.CH1_REG10 = _stpmData();   
        readreg(0xFF);
        stpmregs.CH1_REG11 = _stpmData();   
        readreg(0xFF);
        stpmregs.CH1_REG12 = _stpmData();          
        
        // read another 4 regs from STPM_TOT_REG1
        readreg(STPMADDRESS.STPM_TOT_REG1);
         _stpmData();
        readreg(0xFF);
        stpmregs.TOT_REG1 = _stpmData();
        readreg(0xFF);
        stpmregs.TOT_REG2 = _stpmData();    
        readreg(0xFF);
        stpmregs.TOT_REG3 = _stpmData();    
        readreg(0xFF);
        stpmregs.TOT_REG4 = _stpmData();   
        
        server.log("Measurement:");
		//server.log(format("%08X",stpmregs.DSPEVENT1));
        //server.log(format("%08X",stpmregs.DSPEVENT2));
        server.log("Period = "+format("%08X",stpmregs.DSP_REG1));
        //server.log(format("%08X",stpmregs.DSP_REG2));
        //server.log(format("%08X",stpmregs.DSP_REG3));
        //server.log(format("%08X",stpmregs.DSP_REG4));
        //server.log("PActive" + format("%08X",stpmregs.DSP_REG5));
        //server.log(format("%08X",stpmregs.DSP_REG6));
        //server.log("PReapparent =" + format("%08X",stpmregs.DSP_REG7));
        //server.log("PApparent = " + format("%08X",stpmregs.DSP_REG8));
        //server.log(format("%08X",stpmregs.DSP_REG9));
        //server.log(format("%08X",stpmregs.DSP_REG10));
        //server.log(format("%08X",stpmregs.DSP_REG11));
        //server.log(format("%08X",stpmregs.DSP_REG12));
        //server.log(format("%08X",stpmregs.DSP_REG13));
        server.log("C + V = "+format("%08X",stpmregs.DSP_REG14));
        //server.log(format("%08X",stpmregs.DSP_REG15));
        //server.log(format("%08X",stpmregs.DSP_REG16));
        server.log("PHI = " + format("%08X",stpmregs.DSP_REG17));
        //server.log(format("%08X",stpmregs.DSP_REG18)); 
        //server.log(format("%08X",stpmregs.DSP_REG19));
        //server.log(format("%08X",stpmregs.CH1_REG1));
        //server.log(format("%08X",stpmregs.CH1_REG2));
        //server.log(format("%08X",stpmregs.CH1_REG3));
        //server.log(format("%08X",stpmregs.CH1_REG4));
        server.log("PActive = " + format("%08X",stpmregs.CH1_REG5));
        //server.log(format("%08X",stpmregs.CH1_REG6));
        server.log("PReavtive = " + format("%08X",stpmregs.CH1_REG7));
        server.log("PApparent = " + format("%08X",stpmregs.CH1_REG8));
        //server.log(format("%08X",stpmregs.CH1_REG9));
        //server.log(format("%08X",stpmregs.CH1_REG10));
        //server.log(format("%08X",stpmregs.CH1_REG11));
        //server.log(format("%08X",stpmregs.CH1_REG12));
		//server.log(format("%08X",stpmregs.TOT_REG1));
        //server.log(format("%08X",stpmregs.TOT_REG2));
        //server.log(format("%08X",stpmregs.TOT_REG3));
        //server.log(format("%08X",stpmregs.TOT_REG3));

    },
    
    "updatemeasure" : function(){
        readenergy();
        readpower();
        readRMS();
    },
    
    "readenergy" : function (){
        local raw_energy = stpmregs.CH1_REG4;
        local apparent_calc_energy = uint64(raw_energy);
        
        apparent_calc_energy = apparent_calc_energy.multiply(uint64(defaultenergyFact[0]));
        apparent_calc_energy = apparent_calc_energy.multiply(uint64(8580));
        apparent_calc_energy = apparent_calc_energy.shiftRight(32);
        stpmclass.metroData.energyApparent = apparent_calc_energy.toString();
        server.log(stpmclass.metroData.energyApparent);
        
        raw_energy = stpmregs.CH1_REG1;
        local active_calc_energy = uint64(raw_energy);
        
        active_calc_energy = active_calc_energy.multiply(uint64(defaultenergyFact[0]));
        active_calc_energy = active_calc_energy.multiply(uint64(8580));
        active_calc_energy = active_calc_energy.shiftRight(32);
        stpmclass.metroData.energyActive = active_calc_energy.toString();
        server.log(stpmclass.metroData.energyActive);
   
        
        raw_energy = stpmregs.CH1_REG3;
        local reactive_calc_energy = uint64(raw_energy);
        reactive_calc_energy = reactive_calc_energy.multiply(uint64(defaultenergyFact[0]));
        reactive_calc_energy = reactive_calc_energy.multiply(uint64(8580));
        reactive_calc_energy = reactive_calc_energy.shiftRight(32);
        stpmclass.metroData.energyActive = reactive_calc_energy.toString();
        server.log(stpmclass.metroData.energyReactive);
   
    },
    
    "readpower": function (){
        local neg = 0;
        local raw_power = stpmregs.CH1_REG8;
        if(raw_power < 0){
            neg = 1;
        }
        raw_power =  raw_power & 0x1FFFFFFF;
        raw_power = raw_power << 4;
        raw_power = raw_power >>> 4;
        if(neg==1)
        {
          //server.log("raw neg = "+raw_power);
          raw_power = 268435456 - raw_power;
        }
          
        local apparent_calc_power = uint64(raw_power);
        
        apparent_calc_power = apparent_calc_power.multiply(uint64(defaultpowerFact[0]));
        apparent_calc_power = apparent_calc_power.multiply(uint64(10));
        apparent_calc_power = apparent_calc_power.shiftRight(28);
        if(neg==1)
            stpmclass.metroData.powerApparent = "-"+apparent_calc_power.toString();
        else
            stpmclass.metroData.powerApparent = apparent_calc_power.toString();
        //server.log(stpmclass.metroData.powerApparent);
        
        neg = 0;
        raw_power = stpmregs.CH1_REG5;
        if(raw_power < 0){
            neg = 1;
        }
        raw_power =  raw_power & 0x1FFFFFFF;
        raw_power = raw_power << 4;
        raw_power = raw_power >>> 4;
        if(neg==1)
        {
          //server.log("raw neg = "+raw_power);
          raw_power = 268435456 - raw_power;
        }
          
        local active_calc_power = uint64(raw_power);
        
        //server.log("Power active 1 = " + active_calc_power.toString());
        active_calc_power = active_calc_power.multiply(uint64(defaultpowerFact[0]));
        //server.log("Power active 2 = " + active_calc_power.toString());
        active_calc_power = active_calc_power.multiply(uint64(10));

        active_calc_power = active_calc_power.shiftRight(28);
        //server.log("Power active 4 = " + active_calc_power.toString());
        if(neg==1)
            stpmclass.metroData.powerActive = "-"+active_calc_power.toString();
        else
            stpmclass.metroData.powerActive = active_calc_power.toString();
        
        //server.log("Power active 5 = " + stpmclass.metroData.powerActive);
        
        neg = 0;
        raw_power = stpmregs.CH1_REG7;
        if(raw_power < 0){
            neg = 1;
        }
        raw_power =  raw_power & 0x1FFFFFFF;
        raw_power = raw_power << 4;
        raw_power = raw_power >>> 4;
        local reactive_calc_power = uint64(raw_power);
        
        reactive_calc_power = reactive_calc_power.multiply(uint64(defaultpowerFact[0]));
        reactive_calc_power = reactive_calc_power.multiply(uint64(10));
        reactive_calc_power = reactive_calc_power.shiftRight(28);
        if(neg == 1)
            stpmclass.metroData.powerReactive = "-"+reactive_calc_power.toString();
        else
            stpmclass.metroData.powerReactive = reactive_calc_power.toString();
        //server.log(stpmclass.metroData.powerReactive);
    
    },
    
    "readRMS" : function (){
        //stpmregs.DSP_REG14 = 0x00070CCF;
        local raw_RMS_Voltage = stpmregs.DSP_REG14 & 0x00007FFF;
        local calc_RMS_Voltage  = uint64(raw_RMS_Voltage);
        calc_RMS_Voltage = calc_RMS_Voltage.multiply(uint64(defaultvoltageFact[0])).multiply(uint64(10));
        //server.log(calc_RMS_Voltage);
        calc_RMS_Voltage = calc_RMS_Voltage.shiftRight(15);
        stpmclass.metroData.rmsvoltage = calc_RMS_Voltage.toNumber();
        
        local raw_RMS_Current = stpmregs.DSP_REG14 & 0xFFFF8000;
        raw_RMS_Current = raw_RMS_Current >>> 15;
        local calc_RMS_Current  = uint64(raw_RMS_Current);
        
        calc_RMS_Current = calc_RMS_Current.multiply(uint64(defaultcurrentFact[0])).multiply(uint64(10));
        calc_RMS_Current = calc_RMS_Current.shiftRight(17)
        stpmclass.metroData.rmscurrent = calc_RMS_Current.toNumber();
        
        local period = stpmregs.DSP_REG1 & 0x00000FFF;
        period = period *8;
        //server.log("period =" + period);
        local raw_phi = stpmregs.DSP_REG17 & 0x0FFF0000;
        raw_phi = raw_phi >> 16;
        //server.log("raw phi =" + raw_phi);
        
        local  cal_phi= uint64(raw_phi).multiply(uint64(2880)).div(uint64(period));
        stpmclass.metroData.nbPhase = cal_phi.toNumber();
        //server.log("cal phi =" + stpmclass.metroData.nbPhase);
        //server.log(stpmclass.metroData.nbPhase);
        
        //server.log(stpmregs.DSP_REG14);
    },
}

hts221class <- {
    "connected" : false,
    "I2C_ADDR" : 0xBE,
    "i2c" : null,
    "tempHumid" : null,
    "_init" : function(){
        hts221class.i2c = hardware.i2cFG;
        hts221class.i2c.configure(CLOCK_SPEED_400_KHZ);
        hts221class.tempHumid <- HTS221(hts221class.i2c, hts221class.I2C_ADDR);
        if(tempHumid==null)
            connected = false;
        else
            connected = true;
        //server.log(connected);
        hts221class.tempHumid.setMode(HTS221_MODE.ONE_SHOT);
    },
    "getResolution" : function () {
        local result = hts221class.tempHumid.getResolution();
        server.log(result.temperatureResolution);
        server.log(result.humidityResolution);
        return result;
    
    },
    "getTempHumid" : function () {
        local result = hts221class.tempHumid.read();
        local data = {};
        
        if ("error" in result) {
            // We had an issue taking the reading, lets log it
            server.error(result.error);
        } else {
            local thetemp = result.temperature;
            data.celsius <- thetemp;
            data.humid <- result.humidity;
        }
     
        return data;
    }
}
stpmclass._tableinit();
stpmclass._init();
//stpmclass.setspeed();
stpmclass.autolatch();
stpmclass.readblock();


hts221class._init();

/*
 * GLOBALS
 *
 */
local green = hardware.pinB;
local red = hardware.pinA;
local yellow = hardware.pinC;
local networks = null;
local isScanning = false;
//local ADC1 = hardware.pinK;
//local ADC2 = hardware.pinJ;
local adc_reading = {};
//local adc1 = 0;
//local adc2 = 0;
/*
 * RUNTIME START
 *
 */

/*
 * Configure the status LEDs:
 *   GREEN - device is connected
 *   YELLOW - device is attempting to connect
 *   RED - device is disconnected
 */
local isConnected = server.isconnected();
green.configure(DIGITAL_OUT, (isConnected ? 1 : 0));
red.configure(DIGITAL_OUT, (isConnected ? 0 : 1));
yellow.configure(DIGITAL_OUT, 0);
//ADC1.configure(ANALOG_IN);
//ADC2.configure(ANALOG_IN);

// Register the connection state reporting callback
disconnectionManager.eventCallback = function(event) {
    if ("message" in event) server.log(event.message + " (Timestamp: " + event.ts + ")");

    if ("type" in event) {
        if (event.type == "connected") {
            // Set the LEDs to green on, yellow off, red off
            green.write(1);
            yellow.write(0);
            red.write(0);

            // Relay connection information
            local i = imp.net.info();
            agent.send("send.net.status", i.ipv4);
            //agent.send("send.adc.status", ADC1.read());
            i = "active" in i ? i.interface[i.active] : i.interface[0];
            server.log("Current RSSI " + ("rssi" in i ? i.rssi : "unknown"));
        } else if (event.type == "disconnected") {
            // Set the LEDs to green off, yellow off, red on
            green.write(0);
            red.write(1);
            yellow.write(0);
        } else if (event.type == "connecting") {
            // Set the yellow LED on
            yellow.write(1);
        } else {
            // Just in case, turn all LEDs off
            green.write(0);
            red.write(0);
            yellow.write(0);
        }
    }
};

local humiture;

function blink() {
    //adc1 = format("%.3f", ADC1.read() /65535.0 * 3.3);
    //adc2 = format("%.3f", ADC2.read() /65535.0 * 3.3);
    humiture = hts221class.getTempHumid();
    
    local volt = stpmclass.metroData.rmsvoltage.tofloat()/1000;
    local curr = stpmclass.metroData.rmscurrent.tofloat();
    local cospf = math.cos(PI*stpmclass.metroData.nbPhase.tofloat()/180);
    local pf = stpmclass.metroData.nbPhase.tofloat();
    local pactive = stpmclass.metroData.powerActive.tofloat()/1000;
    local papparent = stpmclass.metroData.powerApparent.tofloat()/1000;
    local preactive = stpmclass.metroData.powerReactive.tofloat()/1000;
    
    adc_reading.te <- format("%.2f",humiture.celsius);
    adc_reading.hu <- format("%.2f",humiture.humid);
    adc_reading.vo <- format("%.2f",volt);
    adc_reading.cu <- format("%.1f",curr);
    adc_reading.stpm <- stpmclass.connected;
    adc_reading.hts <- hts221class.connected;
   //adc_reading.pf <- format("%.2f",math.cos(stpmclass.metroData.nbPhase.tofloat() / 1000));
    //if(stpmclass.stpmregs.CH1_REG8 != 0)
    //{
    //    pf = stpmclass.stpmregs.CH1_REG5.tofloat() /stpmclass.stpmregs.CH1_REG8.tofloat();
    //    if(pf > 1.0)
    //        pf = 1.0;
    //    adc_reading.pf <- format("%.2f",pf);
    //}
    //else {
    //    adc_reading.pf <- "N/A";
    //    pf=1.0;
    //}
    //adc_reading.po <- format("%.2f",stpmclass.metroData.powerApparent.tofloat() /1000);
    adc_reading.pf <- format("%.0f",pf) +"Deg(pf="+format("%.2f",cospf)+")";
    adc_reading.po <- format("%.2f",pactive);
    
    //local m = disconnectionManager._formatTimeString();
    //adc_reading.tr <-m;
    adc_reading.re <-red.read();
    adc_reading.gr <-green.read();
     
    agent.send("send.adc.status", adc_reading);
    
    imp.wakeup(5, blink);
}

function powerblink()
{
    if(!stpmclass.connected){
        
    }
    else
    {
        stpmclass.getmeasure();
        stpmclass.updatemeasure();
    }
    imp.wakeup(5, powerblink);
}
// Set up the connection handler
disconnectionManager.reconnectDelay = 61;
disconnectionManager.start();
//getResolution();
blink();
powerblink();
/*
 * Register handlers for messages sent to the device by its agent
 */
// Define the LED flash function
function setLedState(state) {
    state?red.write(1):red.write(0);
}


// Register a handler function for incoming "set.led" messages from the agent
agent.on("set.led", setLedState);

agent.on("get.wifi.data", function(dummy) {
    // The agent has requested WLAN status information which the web UI will display
    local i = imp.net.info();
    if ("active" in i) {
        // Get the active network interface and make sure it's WiFi
        local item = i.interface[i.active];
        if (item.type == "wifi") {
            // Send the network data
            agent.send("send.net.status", i.ipv4);
            }
    }
});

agent.on("get.wlan.list", function(dummy) {
    // The agent has requested a list of nearby WiFi networks, so begin
    // a new scan if one is not already in progress
    if (!isScanning) {
        isScanning = true;
        imp.scanwifinetworks(function(wlans) {
            // This callback is triggered when the list has been retrieved
            isScanning = false;
            networks = wlans;
            // Send the retrieved WLAN list to the agent
            agent.send("set.wlan.list", networks);
        }.bindenv(this));
    }
}.bindenv(this));
