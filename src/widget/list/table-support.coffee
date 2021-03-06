cola.registerTypeResolver "table.column", (config)->
	return unless config and config.$type
	type = config.$type.toLowerCase()
	if type == "select" then return cola.TableSelectColumn
	else if type == "state" then return cola.TableStateColumn
	return

cola.registerTypeResolver "table.column", (config)->
	if config.columns?.length then return cola.TableGroupColumn
	return cola.TableDataColumn

class cola.TableColumn extends cola.Element
	@attributes:
		parent: null
		name:
			readOnlyAfterCreate: true
		caption:
			refreshColumns: true
		align:
			refreshColumns: true
			enum: [ "left", "center", "right" ]
		visible:
			refreshColumns: true
			type: "boolean"
			defaultValue: true
			refreshStructure: true
		headerTemplate:
			refreshColumns: true

	@events:
		renderHeader: null
		headerClick: null

	constructor: (config)->
		super(config)
		@_id = cola.uniqueId()
		@_name ?= @_id

		@on("attributeChange", (self, arg)=>
			return unless @_table
			attrConfig = @constructor.attributes[arg.attribute]
			return unless attrConfig
			if attrConfig.refreshStructure
				@_table._collectionColumnsInfo()
			return
		)

	_doSet: (attr, attrConfig, value)->
		if attrConfig?.refreshColumns
			@_table?._onColumnChange(attrConfig?.refreshItems)
		return super(attr, attrConfig, value)

	_setTable: (table)->
		@_table._unregColumn(@) if @_table
		@_table = table
		table._regColumn(@) if table
		return

	getTemplate: (type, defaultTemplate)->
		template = @["_real_" + type]
		return template if template isnt undefined

		templateDef = @get(type) or defaultTemplate
		return null unless templateDef

		if typeof templateDef is "string"
			if templateDef.indexOf("<") >= 0
				template = $.xCreate(templateDef)
			else if templateDef.match(/^\#[\w\-\$]*$/)
				template = cola.util.getGlobalTemplate(templateDef.substring(1))
				if template
					div = document.createElement("div")
					div.innerHTML = template
					template = div.firstElementChild
		else if typeof templateDef is "object"
			if templateDef.nodeType
				template = templateDef
			else
				template = $.xCreate(templateDef)

		if not template
			template = @_table.getTemplate(templateDef)

		@["_real_" + type] = template or null
		return template

class cola.TableGroupColumn extends cola.TableColumn
	@attributes:
		columns:
			refreshColumns: true
			refreshItems: true
			setter: (columnConfigs)->
				_columnsSetter.call(@, @_table, columnConfigs)
				return

	_setTable: (table)->
		super(table)
		if @_columns
			for column in @_columns
				column._setTable(table)
		return

class cola.TableContentColumn extends cola.TableColumn
	@attributes:
		width:
			refreshColumns: true
			defaultValue: 100
		valign:
			refreshColumns: true
			enum: [ "top", "center", "bottom" ]
		footerTemplate:
			refreshColumns: true

	@events:
		renderCell: null
		renderFooter: null
		cellClick: null
		footerClick: null

class cola.TableDataColumn extends cola.TableContentColumn
	@attributes:
		dataType:
			readOnlyAfterCreate: true
			setter: cola.DataType.dataTypeSetter
		property: null
		bind: null
		template:
			refreshColumns: true
		sortable:
			refreshColumns: true
		sortDirection:
			refreshColumns: true
		resizeable:
			defaultValue: true

		readOnly: null
		editTemplate: null

class cola.TableSelectColumn extends cola.TableContentColumn
	@attributes:
		width:
			defaultValue: "42px"
		align:
			defaultValue: "center"
	@events:
		headerSelectionChange: null
		itemSelectionChange: null

	renderHeader: (dom)->
		if not dom.firstElementChild
			@_headerCheckbox = checkbox = new cola.Checkbox(
				triState: true
				input: (self, arg)=>
					checked = self.get("checked")
					if checked isnt undefined
						@selectAll(checked)
					if typeof arg.value != "boolean"
						@fire("headerSelectionChange", @, { checkbox: self, oldValue: arg.oldValue, value: arg.value })
			)
			checkbox.appendTo(dom)
		return

	renderCell: (dom, item)->
		if not dom.firstElementChild
			checkbox = new cola.Checkbox(
				bind: @_table._alias + "." + @_table._selectedProperty
				input: (self, arg)=>
					if not @_ignoreCheckedChange
						@refreshHeaderCheckbox()
					arg.item = item
					@fire("itemSelectionChange", @, arg)
					return
			)
			oldRefreshValue = checkbox.refreshValue
			checkbox.refreshValue = ()=>
				oldValue = checkbox._value
				result = oldRefreshValue.call(checkbox)
				if checkbox._value isnt oldValue
					arg =
						model: checkbox.get("model")
						dom: checkbox._dom
						item: item
					@fire("itemSelectionChange", @, arg)
				return result

			checkbox.appendTo(dom)
		return

	refreshHeaderCheckbox: ()->
		return unless @_headerCheckbox
		cola.util.delay(@, "refreshHeaderCheckbox", 50, ()->
			table = @_table
			selectedProperty = table._selectedProperty
			if table._realItems
				i = 0
				selected = undefined
				cola.each @_table._realItems, (item)->
					itemType = table._getItemType(item)
					if itemType is "default"
						i++
						if item instanceof cola.Entity
							s = item.get(selectedProperty)
						else
							s = item[selectedProperty]

						if i is 1
							selected = s
						else if selected isnt s
							selected = undefined
							return false
					return

				@_headerCheckbox.set("value", selected)
			return
		)
		return

	selectAll: (selected)->
		table = @_table
		selectedProperty = table._selectedProperty
		if table._realItems
			@_ignoreCheckedChange = true
			cola.each table._realItems, (item)=>
				itemType = table._getItemType(item)
				if itemType is "default"
					if item instanceof cola.Entity
						item.set(selectedProperty, selected)
					else
						item[selectedProperty]
						table.refreshItem(item)
				return

			setTimeout(()=>
				@_ignoreCheckedChange = false
				return
			, 100)
		return

class cola.TableStateColumn extends cola.TableContentColumn
	@attributes:
		width:
			defaultValue: "36px"
		align:
			defaultValue: "center"

	renderCell: (dom, item)->
		if item instanceof cola.Entity
			message = item.getKeyMessage()
			if message
				if typeof message is "string"
					message =
						type: "error"
						text: message
				state = message.type
			else
				if item.state is cola.Entity.STATE_NEW
					state = "new"
				if item.state is cola.Entity.STATE_MODIFIED
					state = "modified"
			dom.className = "state " + (state or "")
		return