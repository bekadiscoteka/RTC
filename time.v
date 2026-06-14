`define INCR(var) var <= var + 1
`define DECR(var) var <= var - 1

module pll #(
	parameter [31:0] DIV= 50_000_000  // 50 Mhz
)(
	output reg tick,
	
	input clk, rst_n
);
	localparam CNT_MAX = DIV - 1;
	reg [31:0] counter;
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin 
			counter <= 0;
			tick <= 0;
		end
		else if (counter >= CNT_MAX) begin
			counter <= 0;
			tick <= 1;
		end
		else begin 
			counter <= counter + 1;
			tick <= 0;
		end
	end
endmodule

module TIME_REPORTER(
	output reg	[13:0] 	rtc_year,
	output reg	[3:0] 	rtc_month,
	output reg	[4:0] 	rtc_day, rtc_hour,
	output wire	[2:0] 	rtc_dow,
	output reg	[5:0] 	rtc_minute, rtc_second,

	output reg	alarm_out,
			timer_out,
			error,

	input	clk_50Mhz,
		rst_n,
		wr_en,
		alarm_en,
		timer_en,
	
	input [13:0] data_in,
	input [3:0] addr
	
	);


	/* clk divider */
	
	wire second_tick;

	pll #(.DIV(50_000_000)) pll_inst(
		.clk(clk_50Mhz),
		.rst_n(rst_n),
		.tick(second_tick)
	);
		
	/* register files */

	reg [13:0] alarm_year;
	reg [3:0]  alarm_month;
	reg [4:0] alarm_day;
	reg [4:0] alarm_hour, timer_hour;
	reg [5:0] alarm_minute, timer_minute,
		 alarm_second, timer_second;
	
	/* months */

	localparam	JAN=1,
			FEB=2,
			MAR=3,
			APR=4,
			MAY=5,
			JUN=6,
			JUL=7,
			AUG=8,
			SEP=9,
			OCT=10,
			NOV=11,
			DEC=12;

	/* day of week */

	day_of_week zeller(
		.dow(rtc_dow),

		.year(rtc_year),
		.month(rtc_month),
		.day(rtc_day)
	);

	/* month and day logic */
	reg [4:0] maxday, alarm_maxday;
	
	always @* begin
		case (rtc_month)
			JAN, MAR, MAY, JUL, AUG, OCT, DEC: maxday = 31;
			FEB: begin
				maxday = 28;	
				if ( ((rtc_year[1:0] == 0) && ((rtc_year % 100) != 0)) || (rtc_year % 400) == 0) 
					maxday = 29;
			end
			default: maxday = 30;
		endcase
	end

	always @* begin
		case (alarm_month)
			JAN, MAR, MAY, JUL, AUG, OCT, DEC: alarm_maxday = 31;
			FEB: begin
				alarm_maxday = 28;	
				if ( ((alarm_year[1:0] == 0) && ((alarm_year % 100) != 0)) || (alarm_year % 400) == 0) 
					alarm_maxday = 29;
			end
			default: alarm_maxday = 30;
		endcase
	end

	/* alarm/timer logic */
	always @* begin
		alarm_out = 0;
		timer_out = 0;
		if (alarm_en) begin
			if (
				alarm_year == rtc_year 
				&& alarm_month == rtc_month 
				&& alarm_day == rtc_day 
				&& alarm_hour == rtc_hour 
				&& alarm_minute == rtc_minute 
				&& alarm_second == rtc_second
			) begin
				alarm_out = 1;
			end
		end
		
		if (timer_en) begin
			if ( {timer_hour, timer_minute, timer_second} == 0 ) 
				timer_out = 1;
		end

	end

	/* register address mapping */
	
	localparam	RTC_Y_ADDR=4'H0,
			RTC_M_ADDR=4'H1,
			RTC_D_ADDR=4'H2,
			RTC_H_ADDR=4'H3,
			RTC_MIN_ADDR=4'H4,
			RTC_SEC_ADDR=4'H5,
			
			ALM_Y_ADDR=4'H6,
			ALM_M_ADDR=4'H7,
			ALM_D_ADDR=4'H8,
			ALM_H_ADDR=4'H9,
			ALM_MIN_ADDR=4'HA,
			ALM_SEC_ADDR=4'HB,

			TMR_H_ADDR=4'HC,
			TMR_MIN_ADDR=4'HD,
			TMR_SEC_ADDR=4'HE;


	/* sequential logic */

	wire rtc_minute_ismax = rtc_second >= 59;
	wire rtc_hour_ismax = (rtc_second >= 59) && (rtc_minute >= 59);
	wire rtc_day_ismax = (rtc_second >= 59) && (rtc_minute >= 59) && (rtc_hour >= 23);
	wire rtc_month_ismax = (rtc_second >= 59) && (rtc_minute >= 59) && (rtc_hour >= 23) && (rtc_day >= maxday); 
	wire rtc_year_ismax = (rtc_second >= 59) && (rtc_minute >= 59) && (rtc_hour >= 23) && (rtc_day >= maxday) && (rtc_month >= 12); 

	always @(posedge clk_50Mhz, negedge rst_n) begin
		if (!rst_n) begin
			rtc_year <= 1990;		
			rtc_month <= 1;
			rtc_day <= 1;
			rtc_hour <= 0;
			rtc_minute <= 0;
			rtc_second <= 0;

			alarm_year <= 1990;
			alarm_month <= 1;
			alarm_day <= 1;
			alarm_hour <= 0;
			alarm_minute <= 0;
			alarm_second <= 0;

			error <= 0;
		end
		else if ( wr_en ) begin
			case (addr)
				RTC_Y_ADDR: begin
					if (data_in <= 9999 && data_in >= 1990) begin
						rtc_year <= data_in[13:0];
						error <= 0;
					end
					else error <= 1; 
				end
				RTC_M_ADDR: begin
					if (data_in > 0 && data_in <= 12) begin
						rtc_month <= data_in[3:0];
						error <= 0;
					end
					else error <= 1;

				end
				RTC_D_ADDR: begin
					if (data_in > 0 && data_in <= maxday) begin
						rtc_day <= data_in[4:0];
						error <= 0;
					end
					else error <= 1;
				end
				RTC_H_ADDR: begin
					if (data_in < 24) begin
						rtc_hour <= data_in[4:0];
						error <= 0;
					end
					else error <= 1;
				end
				RTC_MIN_ADDR: begin
					if (data_in < 60) begin
						rtc_minute <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end
				RTC_SEC_ADDR: begin
					if (data_in < 60) begin
						rtc_second <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end

				ALM_Y_ADDR: begin
					if (data_in <= 9999 && data_in >= 1990) begin
						alarm_year <= data_in[13:0];	
						error <= 0;
					end
					else error <= 1;
				end
				ALM_M_ADDR: begin
					if (data_in > 0 && data_in <= 12) begin
						alarm_month <= data_in[3:0];
						error <= 0;
					end
					else error <= 1;
				end
				ALM_D_ADDR: begin
					if (data_in > 0 && data_in <= maxday) begin
						alarm_day <= data_in[4:0];
						error <= 0;
					end
					else error <= 1;
				end
				ALM_H_ADDR: begin
					if (data_in < 24) begin
						alarm_hour <= data_in[4:0];
						error <= 0;
					end
					else error <= 1;
				end
				ALM_MIN_ADDR: begin
					if (data_in < 60) begin
						alarm_minute <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end
				ALM_SEC_ADDR: begin
					if (data_in < 60) begin
						alarm_second <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end

				TMR_H_ADDR: begin
					if (data_in < 24) begin
						timer_hour <= data_in[4:0];
						error <= 0;
					end
					else error <= 1;
				end
				TMR_MIN_ADDR: begin
					if (data_in < 60) begin
						timer_minute <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end
				TMR_SEC_ADDR: begin
					if (data_in < 60) begin
						timer_second <= data_in[5:0];
						error <= 0;
					end
					else error <= 1;
				end
				default: error <= 1;
			endcase
		end

		else begin
			error <= 0;

			if (second_tick) begin
				if (rtc_year_ismax)
					rtc_year <= rtc_year >= 9999 ? 0 : rtc_year + 1;
				if (rtc_month_ismax)
					rtc_month <= rtc_month >= 12 ? 1 : rtc_month + 1;
				if (rtc_day_ismax)
					rtc_day <= (rtc_day >= maxday) ? 1 : rtc_day + 1;
				if (rtc_hour_ismax)
					rtc_hour <= (rtc_hour >= 23) ? 0 : rtc_hour + 1;
				if (rtc_minute_ismax) 
					rtc_minute <= (rtc_minute >= 59) ? 0 : rtc_minute + 1;
				rtc_second <= (rtc_second >= 59) ? 0 : rtc_second + 1;


				if (timer_en) begin
					if (timer_second == 0) begin
						if (timer_minute == 0) begin
							if (timer_hour == 0) 
								timer_second <= 0;
							else begin
								timer_second <= 59;
								timer_minute <= 59;
								`DECR(timer_hour);
							end
						end
						else begin 
							timer_second <= 59;
							`DECR(timer_minute);
						end

					end
					else `DECR(timer_second);
				end

			end
		end
	end
	
endmodule

module day_of_week (
    input  wire [13:0] year,   // 1990..9999
    input  wire [3:0]  month,  // 1..12
    input  wire [4:0]  day,    // 1..31
    output wire [2:0]  dow     // 0=Sun, 1=Mon, ..., 6=Sat
);

    // Adjusted month and year (Jan/Feb treated as months 13/14 of prev year)
    wire [3:0]  m_adj  = (month <= 2) ? month + 12 : month;
    wire [13:0] y_adj  = (month <= 2) ? year - 1   : year;

    // Century and year-within-century
    wire [6:0]  k = y_adj % 100;       // year within century
    wire [6:0]  j = y_adj / 100;       // century

    // Zeller's congruence (all integer arithmetic)
    // h = (day + floor(13*(m+1)/5) + k + floor(k/4) + floor(j/4) + 5*j) mod 7
    wire [19:0] zeller = day
                       + (13 * (m_adj + 1)) / 5
                       + k
                       + (k / 4)
                       + (j / 4)
                       + 5 * j;

    wire [2:0] h = zeller % 7;

    // Remap: Zeller gives 0=Sat,1=Sun; we want 0=Sun..6=Sat
    assign dow = (h + 6) % 7;

endmodule
