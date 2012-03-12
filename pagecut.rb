#!/usr/bin/ruby
# coding:utf-8

@gridstep=50
@color_of_grid='rgb(0,0, 255,0.3)'
@color_of_area='rgba(180,180,0,0.5)'
@djvuenc = {
  '0'=>'',
  '21'=>'-slice 64+9+2',                # High compression 21% from default 
  '23'=>'-slice 64+9+3',                # High compression 23% from default 
  '35'=>'-slice 64+9+8 -decibel 35',    # High compression 35% from default 
  '64'=>'-slice 66+10+9+6 -decibel 38', # 64 % from default
  'morequality'=>'-slice 72+11+10+10',  # 113%
}
@c44opts=@djvuenc['0']

puts "pagecut.rb"
if ARGV.size != 2
  puts "
ИСПОЛЬЗОВАНИЕ: pagecut.rb <действие> <файл конфигурации>
ДЕЙСТВИЯ: 
          stat - Показать статистику
          test - Сгенерировать тест
          crop - Порезать
          djvu - Собрать DJVU-файл
"
  exit
end

@mode = ARGV[0]
@config = File.open(ARGV[1]).readlines    


@srcfilemask = "jpeg/%04d.jpg"
@mediummask = "temp/%04d-%d"
@testfilemask = "test/%04d-%d.jpg"
@outfilemask = "temp/%04d-%d.tiff"

@jpegs = []
@djvus=[]
@stat={}
@maxpage=0
@totalcount=0
@area = []

def page_make(pagen, crops)
  @maxpage = pagen if pagen > @maxpage
  crops.each_index do |ci|
    @totalcount += 1
    puts "page %d/%d" % [pagen, ci+1]
    @stat[pagen]={} if ! @stat.has_key?(pagen)
    @stat[pagen][ci+1]=0 if ! @stat[pagen].has_key?(ci+1)
    @stat[pagen][ci+1]+=1
    srcname = @srcfilemask  % [pagen]
    cropname = @outfilemask % [pagen, ci+1]
    raise "Не JPEG файл #{srcname}" if not `identify #{srcname}`.match(/^[-\/_.A-Za-z0-9]* JPEG (\d*)x(\d*)/)
    imgsizex, imgsizey = Integer($1), Integer($2)
    area = crops[ci].split(',').collect { |i| Integer(i.strip) }
#    3.times { |j| area[j] = @area[j] if area.count == j }
    area[2] = @area[2] if area.count == 2
    area[3] = @area[3] if area.count == 3
    @area = area
    case 
    when @mode == 'test'
      testname = @testfilemask % [pagen, ci+1]
      raise "Площадь обрезания должна быть вида: X, Y, Width, Height: " if area.size >4
      grid=[]
      (imgsizex/@gridstep).times {|i| grid << "line %d 0 %d %d" % [@gridstep*i, @gridstep*i, imgsizey] }
      (imgsizey/@gridstep).times {|i| grid << "line 0 %d %d %d" % [@gridstep*i, imgsizex, @gridstep*i ] }
      `convert #{srcname} -quality 50 -fill '#{@color_of_grid}' -draw '#{grid.join(' ')}' -fill '#{@color_of_area}' -draw 'rectangle #{area[0]} #{area[1]} #{area[2]+area[0]} #{area[3]+area[1]}' #{testname}`
    when @mode=='crop'
      `convert #{srcname} -crop #{area[2]}x#{area[3]}+#{area[0]}+#{area[1]} -normalize -despeckle #{cropname}`
    when @mode=='djvu'
      mediumname = @mediummask % [pagen, ci+1]
      `convert #{cropname} #{mediumname}.pnm`
      @djvus  << "#{mediumname}.djvu"
      `c44 #{@c44opts} #{mediumname}.pnm #{mediumname}.djvu`
      `rm -f #{mediumname}.pnm`
    end
  end
end

case
  when @mode=='test'
    `rm test/*.jpg`
  end

@config.each do |pline|
  next if pline.strip!.empty? or pline[0]=='#'
  crop, pages = pline.split('/')
  crop = crop.split(';')
  pages.split(',').each do |s|
    if s.strip.match(/(\d+)\s*-\s*(\d+)/)
      Integer($1).upto( Integer($2)) { |i| page_make(i, crop) }
    else
      page_make(Integer(s),crop)
    end
  end
end

missed, twice = [], []
@maxpage.times do |p| 
  if @stat.has_key?(p+1)
    @stat[p+1].each { |k,v| if v>1 then twice << String(p+1); break; end }
  else
    missed << String(p+1) if ! @stat.has_key?(p+1)
  end
end
case
  when @mode=='djvu'
    `djvm -c #{ARGV[1]}.djvu #{@djvus.uniq.sort.join(' ')}`
    `rm -f #{@djvus.uniq.join(' ')}`
  end

puts "---СТАТИСТИКА---"
puts "СТРАНИЦ: #{@totalcount}"
puts "ПОСЛЕДНЯЯ СТРАНИЦА: #{@maxpage}"
puts "ПРОПУЩЕННЫЕ ЛИСТЫ: #{missed.join(', ')}" if ! missed.empty?
puts "ОБРАБОТАННЫЕ БОЛЕЕ ОДНОГО РАЗА ЛИСТЫ: #{twice.join(', ')}" if ! twice.empty?

