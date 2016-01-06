{ROOT, layout, _, $, $$, React, ReactBootstrap, success, warn} = window
{OverlayTrigger, Tooltip, Label} = ReactBootstrap
{join} = require 'path-extra'
__ = i18n.main.__.bind(i18n.main)
__n = i18n.main.__n.bind(i18n.main)

showItemDevResultDelay = if window.config.get('poi.delayItemDevResult', false) then 6200 else 500


CountdownTimer = require './countdown-timer'
CountdownLabel = React.createClass
  getInitialState: ->
    style: 'default'
  tick: (timeRemaining) ->
    style = switch
      when timeRemaining > 600 and @props.isLSC then 'danger'
      when timeRemaining > 600 then 'primary'
      when timeRemaining >  0  then 'warning'
      when timeRemaining is 0  then 'success'
      else 'default'
    @setState {style: style} if style isnt @state.style
  render: ->
    <Label className="kdock-timer" bsStyle={@state.style}>
    {
      if @props.completeTime >= 0
        <CountdownTimer countdownId={"kdock-#{@props.dockIndex}"}
                        completeTime={@props.completeTime}
                        tickCallback={@tick}
                        completeCallback={@props.notify} />
    }
    </Label>


class KDockInfo
  constructor: ->
    @empty()
  empty: ->
    @name = __ 'Empty'
    @material = []
    @completeTime = -1
  setLocked: ->
    @name = __ 'Locked'
    @material = []
    @completeTime = -1
  update: (kdock) ->
    switch kdock.api_state
      when -1 then @setLocked()
      when 0  then @empty()
      when 2, 3
        @name = window.$ships[kdock.api_created_ship_id].api_name
        @material =  [
          kdock.api_item1
          kdock.api_item2
          kdock.api_item3
          kdock.api_item4
          kdock.api_item5
        ]
        @completeTime = kdock.api_complete_time

KdockPanel = React.createClass
  canNotify: false
  getInitialState: ->
    docks: [1..5].map () -> new KDockInfo
  handleResponse: (e) ->
    {path, body, postBody} = e.detail
    {docks} = @state
    switch path
      when '/kcsapi/api_start2'
        # Do not notify before entering the game
        @canNotify = false
      when '/kcsapi/api_port/port'
        @canNotify = true
      when '/kcsapi/api_get_member/kdock', '/kcsapi/api_req_kousyou/getship'
        kdocks = body
        kdocks = body.api_kdock if path is '/kcsapi/api_req_kousyou/getship'
        for kdock in kdocks
          docks[kdock.api_id].update kdock
        @setState
          docks: docks
      when '/kcsapi/api_req_kousyou/createship_speedchange'
        if body.api_result == 1
          docks[postBody.api_kdock_id].completeTime = 0
          @setState
            docks: docks
      when '/kcsapi/api_req_kousyou/createitem'
        if body.api_create_flag == 0
          setTimeout warn.bind(@, __("The development of %s was failed.",
            "#{window.i18n.resources.__ $slotitems[parseInt(body.api_fdata.split(',')[1])].api_name}")),
            showItemDevResultDelay
        else if body.api_create_flag == 1
          setTimeout success.bind(@, __("The development of %s was successful.",
            "#{window.i18n.resources.__ $slotitems[body.api_slot_item.api_slotitem_id].api_name}")),
            showItemDevResultDelay
  componentDidMount: ->
    window.addEventListener 'game.response', @handleResponse
  componentWillUnmount: ->
    window.removeEventListener 'game.response', @handleResponse
  getMaterialImage: (idx) ->
    path = join(ROOT, 'assets', 'img', 'material', "0#{idx}.png")
    <img src={path} className="material-icon" />
  constructionIcon: join(ROOT, 'assets', 'img', 'operation', 'build.png')
  notify: ->
    return if not @canNotify
    completedShips = @state.docks.slice(1).filter(
      (dock) -> 0 <= dock.completeTime < new Date().getTime() + 1000).map(
      (dock) -> i18n.resources.__ dock.name).join(', ')
    notify "#{completedShips} #{__ 'built'}",
      type: __ "Construction"
      icon: @constructionIcon
  render: ->
    <div>
    {
      for i in [1..4]
        dockName = i18n.resources.__ @state.docks[i].name
        isInUse = @state.docks[i].completeTime >= 0
        isLSC = isInUse and @state.docks[i].material[0] >= 1000
        content = <div className="panel-item kdock-item">
                    <span className="kdock-name">{dockName}</span>
                    <CountdownLabel dockIndex={i}
                                    completeTime={@state.docks[i].completeTime}
                                    isLSC={isLSC}
                                    notify={@notify} />
                  </div>

        if isInUse
          <OverlayTrigger key={i} placement='top' overlay={
            <Tooltip id="kdock-material-#{i}">
              {
                style = if isLSC then {color: '#D9534F', fontWeight: 'bold'} else null
                <span style={style}>{dockName}<br /></span>
              }
              {@getMaterialImage 1} {@state.docks[i].material[0]}
              {@getMaterialImage 2} {@state.docks[i].material[1]}
              {@getMaterialImage 3} {@state.docks[i].material[2]}
              {@getMaterialImage 4} {@state.docks[i].material[3]}
              {@getMaterialImage 7} {@state.docks[i].material[4]}
            </Tooltip>
          }>
            {content}
          </OverlayTrigger>
        else
          <span key={i}>
            {content}
          </span>
    }
    </div>

module.exports = KdockPanel
