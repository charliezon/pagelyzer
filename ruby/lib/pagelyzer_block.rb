#!/usr/bin/ruby1.9.1
#-*- mode: ruby; encoding: utf-8 -*-
# Andrés Sanoja
# UPMC - LIP6
#
# block.rb
#
# Requires: Ruby 1.9.1+ (1.8.x versions won't work) and rubygems 1.3.7+
#
# Copyright (C) 2011, 2012 Andrés Sanoja, Université Pierre et Marie Curie -
# Laboratoire d'informatique de Paris 6 (LIP6)
#
# Contributors: Stephane Gançarski - LIP6
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# classes intended to represent a block 
# - block: general block methods and data
# - CompositeBlock: blocks that area formed when merging separators but that doesn't 
#   correspond to a HTML node

class Block

	attr_accessor :id,:parent,:text,:host,:user_id,:browser_id,:job_id
	attr_accessor :gid,:parent_gid,:candidates,:path,:children,:parent,:weight,:rule
	attr_accessor :hsep,:vsep,:doc, :min_x, :min_y, :max_x, :max_y

	def initialize()
		@id = 0
		@text = ""
		@children = []
		@candidates = []
		@path = []
		@weight=0
		@parent=nil
		@rule = nil
		@hsep = []
		@vsep = []
		@doc = 0
		@links = []
		@images = []
		@text = []
	end

	# SID is the segment hierarchical ID, for example the first Block would be 1, 
	# his first child would be 1-1, and so on
	def sid
		unless @parent.nil?
			return "#{@parent.sid}-#{@parent.children.index(self)+1}"
		else
			return "1"
		end
	end

	#get the polygon representation of the block
	def polygon
		@path.collect {|p| [p.x,p.y]}
	end
	
	#get the list of points in the block polygon
	def points
		polygon.flatten
	end

	def add_child(child)
		child.parent = self
		@weight = child.weight.to_i if child.weight.to_i > @weight.to_i
		@children.push child
	end

	def delete_child(child)
		k=0
		@children.each do |b|
			if child.id == b.id
				@children[k]=nil
				@children.delete(nil)
				break
			end
			k+=1
		end
	end
	
	def process_extra_vixml2
		@links = @links.uniq
		@images = @images.uniq
		@text = @text.uniq
	end
	
	def process_extra_links(c)
		c.search("*").each do |tag|
				if ['a','img'].include? tag.name.downcase
					@links.push tag	
					@images.push tag
					@text.push Sanitize.clean(tag.inner_text)
				else
					@text.push Sanitize.clean(tag.inner_text) unless undesirable_node?(tag)
				end
			end
	end
	
	def process_extra_vixml(nodes)
		nodes.each do |c|
			process_extra_links c
		end
		process_extra_vixml2
	end

	def get_proper_doc_with(nodes)
		if nodes.collect {|x| x.name.upcase}.include? "BODY"
			return 0
		else
			if rule.weight > @doc
				return rule.weight 
			else
				return 0
			end
		end
	end
	
	def add_candidate(nodes,rule)
		nodes.each do |n|
			@candidates << n
		end
		@rule = rule
		if @rule.action.doc.nil?
			@doc = get_proper_doc_with nodes
		else
			@doc = @rule.action.doc
		end
		
		process_path
		
		#extracting links for ViXML generation
		process_extra_vixml nodes
		
		
		#puts "#{sid} #{@images.size	}"
	end

	#construct the block polygon
	
	def iterate_candidates
		x=[]
		y=[]
		@candidates.each do |n|
			y.push [n['elem_top'].to_f,n['elem_height'].to_f]
			x.push [n['elem_left'].to_f,n['elem_width'].to_f]
		end
		return x.flatten!,y.flatten!
	end
	
	def get_actual_path
		x=[]
		y=[]
		@path.each do |p|
			x.push p.x
			y.push p.y
		end
		return x,y
	end
	
	def set_coord(x,y)
		@min_x = x.min
		@max_x = x.max
		@min_y = y.min
		@max_y = y.max
	end
	
	def set_new_path_with(x,y)
		@path.push Point.new(x.min,y.min)
		@path.push Point.new(x.min,y.max)
		@path.push Point.new(x.max,y.max)
		@path.push Point.new(x.max,y.min)
	end
	
	def process_path
		unless @candidates == []
			@path = []
			
			x,y = iterate_candidates
			
			unless x==[] or y==[]
				set_new_path_with x,y
			end
		else
			x,y = get_actual_path
		end
		
		 set_coord x,y
	end

	def minimum_distance_to?(block)
		min = 10000000
		@path.each do |p1|
			block.path.each do |p2|
				d = p1.distance_to? p2
				min = d if d<min 
			end
		end
	min
	end

	def candidates_name_list
		@candidates.collect {|x| x.name}
	end

	def candidates_id_list
		@candidates.collect {|x| x['uid']}
	end

	def candidates_text_based?
		@candidates.collect {|node| (virtual_text?(node) or text?(node)) ? true : false}
		ret=true
		@candidates.each {|n| ret = ret and n}
		ret
	end

	def candidates_structure
		@candidates.collect {|x| x.search("*").collect {|y| classify(y)}}.flatten
	end

	def candidates_background_color_list
		@candidates.collect {|node| rgb2hex(node['background_color'])}.uniq
	end

	def candidates_font_size_list
		@candidates.collect {|node| node['font_size'].to_i}.uniq
	end

	def centroid_x
		@path.reduce(0) {|sum,p| sum+=p.x} / @path.size
	end

	def centroid_y
		@path.reduce(0) {|sum,p| sum+=p.y} / @path.size
	end

	# not used, next step delete it
	
	#=== begin commented/deleted code
	
	#~ def calculate_max_y
		#~ ch_max_y = 0
		#~ final_max_y = @path.collect {|p| p.y}.max.to_f
		#~ unless @children == []
			#~ ch_max_y = @children.collect {|child| child.max_y}.max.to_f
		#~ end
		#~ final_max_y = ch_max_y if ch_max_y > final_max_y
		#~ final_max_y
	#~ end
#~ 
	#~ def calculate_max_x
		#~ ch_max_x = 0
		#~ final_max_x = @path.collect {|p| p.x}.max.to_f
		#~ unless @children == []
			#~ ch_max_x = @children.collect {|child| child.max_x}.max.to_f
		#~ end
		#~ final_max_x = ch_max_x if ch_max_x > final_max_x
		#~ final_max_x
	#~ end
#~ 
	#~ def calculate_min_y
		#~ ch_min_y = 999999999999999999
		#~ final_min_y = @path.collect {|p| p.y}.min.to_f
		#~ unless @children == []
			#~ ch_min_y = @children.collect {|child| child.min_y}.min.to_f
		#~ end
		#~ final_min_y = ch_min_y if ch_min_y < final_min_y
		#~ final_min_y
	#~ end
#~ 
	#~ def calculate_min_x
		#~ ch_min_x = 999999999999999999
		#~ final_min_x = @path.collect {|p| p.x}.min.to_f
		#~ unless @children == []
			#~ ch_min_x = @children.collect {|child| child.min_x}.min
		#~ end
		#~ final_min_x = ch_min_x if ch_min_x < final_min_x
		#~ final_min_x
	#~ end
    #=== end commented/deleted code

	#detect overlapped siblings blocks
	def detect_overlapping
		@children.each do |child1|
			@children.each do |child2|
				unless child1.id == child2.id
					if child1.overlaps?(child2)
						#not functional yet
					end
				end
			end
		end
		unless @children.nil?
			@children.each do |c|
				c.detect_overlapping
			end
		end
	end

	def overlaps?(block)
		@path.each do |p|
			if p.into?(block.path,max_y)
				return true
				break
			end
		end
		return false
	end
	
	
	def weight
		"<weight>\n#{@doc}\n</weight>\n"
	end
	
	def block_open
		"<Block Ref=\"Block#{sid}\" internal_id='#{@id}' ID=\"$BLOCK_ID$\" Pos=\"WindowWidth||PageRectLeft:#{@min_x} WindowHeight||PageRectTop:#{@min_y} ObjectRectWidth:#{@max_x - @min_x} ObjectRectHeight:#{@max_y - @min_y}\" Doc=\"#{@doc}\">\n"
	end
	def block_close
		"</Block>"
	end
	def candidate_path
		@candidates.collect {|c| "<path>#{c.path},#{c["elem_left"]},#{c["elem_top"]},#{c["elem_width"]},#{c["elem_height"]},#{c["id"]},#{c["uid"]}</path>\n"}.join("")
	end
	def paths
		"<Paths>\n#{candidate_path}</Paths>\n"
	end
	#~ def xlinks_det_proc_asg(lid,link,iid)
		#~ s=""
		#~ unless lid.include? iid
			#~ s = "<link ID=\"#{iid}\" Name=\"#{escape_html(link.inner_text.strip)}\" Adr=\"#{escape_html(link[:href])}\"/>"
		#~ end
		#~ s
	#~ end
	#~ def xlinks_det_proc(lid,link)
		#~ iid = crypt(escape_html(link.inner_text.strip) + escape_html(link[:href]))
		#~ s = xlinks_det_proc_asg(lid,link,iid)
		#~ return iid,s
	#~ end
	#~ def xlinks_det
		#~ lid = []
		#~ sl = ""
		#~ @links.uniq.each do |link|
			#~ unless malformed?(link)
				#~ iid,s = xlinks_det_proc(lid,link)
				#~ lid.push iid
				#~ sl += s
			#~ end
		#~ end
		#~ return lid,sl
	#~ end
	def xlinks
		src="<Links ID=\"$LINKS_ID$\" IDList=\"$ID_LIST_LINKS$\">\n"
		lid,sl = xproc_det(@links,2)
		src.gsub!('$ID_LIST_LINKS$',lid.join(','))
		src.gsub!('$LINKS_ID$',crypt(sl))
		src += "</Links>\n"
		return src
	end
	#~ def ximgs_det_proc_asg(lim,image,iid)
		#~ s=""
		#~ unless lim.include? iid
			#~ lim.push iid
			#~ s = "<img ID=\"#{iid}\" Name=\"#{escape_html(image[:alt])}\" Src=\"#{escape_html(image[:src])}\"/>"
		#~ end
		#~ s
	#~ end
	#~ def ximgs_det_proc(lim,image)
		#~ iid = crypt(escape_html(image['alt'])+escape_html(image['src']))
		#~ s = ximgs_det_proc_asg(lim,image,iid)
		#~ return iid,s
	#~ end
	#~ def ximgs_det
		#~ lim = []
		#~ si = ""
		#~ @images.uniq.each do |image|
			#~ unless malformed?(image) 
				#~ iid,s = ximgs_det_proc(lim,image)
				#~ lim.push iid
				#~ si += s
			#~ end
		#~ end
		#~ return lim,si
	#~ end
	#*******
	def fmtimage(iid,v1,v2)
		"<img ID=\"#{iid}\" Name=\"#{escape_html(v1)}\" Src=\"#{escape_html(v2)}\"/>"
	end
	def fmtlink(iid,v1,v2)
		"<link ID=\"#{iid}\" Name=\"#{escape_html(v1)}\" Adr=\"#{escape_html(v2)}\"/>"
	end
	def xproc_det_proc_asg(list,item,iid,v1,v2,type)
		s=""
		unless list.include? iid
			list.push iid
			if type==1
				s = fmtimage(iid,v1,v2)
			else
				s = fmtlink(iid,v1,v2)
			end
		end
		s
	end
	def  xproc_det_proc(list,item,v1,v2,type)
		iid = crypt(escape_html(v1)+escape_html(v2))
		#~ iid = crypt(escape_html(link.inner_text.strip) + escape_html(link[:href]))
		s = xproc_det_proc_asg(list,item,iid,v1,v2,type)
		return iid,s
	end
	def xproc_det(collection,type)
		list = []
		text = ""
		collection.each do |item|
			unless malformed?(item)
				if type==1
					iid,s = xproc_det_proc(list,item,item['alt'],item['src'],type) 
				else
					iid,s = xproc_det_proc(list,item,item.inner_text.strip,item[:href],type)
				end
				list.push iid
				text += s
			end
		end
		return list,text
	end
	# *******
	def ximgs
		src = "<Imgs ID=\"$IMGS_ID$\" IDList=\"$ID_LIST_IMAGES$\">\n"
		lim,si = xproc_det(@images,1)
		#~ lim,si = ximgs_det
		src.gsub!('$ID_LIST_IMAGES$',lim.join(','))
		src.gsub!('$IMGS_ID$',crypt(si))
		src += si
		src += "</Imgs>\n"
		return src
	end
	def xtext
		@text.delete(nil)
		@text.delete('')
		@text.collect! {|t| 
			t.gsub(/(?<!\n)\n(?!\n)/,' ').gsub(/^$\n/,'').gsub(/\s+/,' ').strip
		}
		txt = escape_html(@text.join(","))
		return "<Txts ID=\"#{crypt(txt)}\" Txt=\"#{txt}\"/>\n"
	end
	
	# get the ViXML format representation of the block
	
	def process_children
		src = ""
		unless @children.empty?
			@children.each do |child|
				src += child.to_xml
			end
		end
		return src
	end
	
	def to_xml
		cnt =  weight + paths + xlinks + ximgs + xtext 
		src = block_open.gsub('$BLOCK_ID$',crypt(cnt)) + cnt
		src += process_children
		src += block_close
		return src
	end

end

class CompositeBlock < Block
end