import requests
from bs4 import BeautifulSoup
import lxml
import os
import time
import csv


def get_data(url):
    headers={
        'accept': '*/*',
        'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/102.0.0.0 Safari/537.36'
    }
    req=requests.get(url=url,headers=headers) #переменная запроса
    
    with open (r'C:\Users\Media\parsing\ufc\all_events.html','w', encoding='utf-8') as file: #записываем страницу
        file.write(req.text)
        
    with open (r'C:\Users\Media\parsing\ufc\all_events.html', encoding='utf-8') as file: #открываем страницу
        src=file.read()
        
    soup=BeautifulSoup(src,'lxml') #парсим страницу
    
    events=soup.find_all('i',class_='b-statistics__table-content') #находим нужный класс
    
    events2=soup.find_all('td', class_='b-statistics__table-col b-statistics__table-col_style_big-top-padding')
    
    #со сложными условиями по типу not in генераторы не прокатывают
    events_url_list=[]  #список ссылок на ивенты
    for events_url in events:
        events_url=events_url.find('a').get('href')
        if events_url not in events_url_list:
            events_url_list.append(events_url)
        else:
            pass
    
    events_url_list.pop(0) #удаляем первый элемент из списка, т.к. он нам не нужОн
    
    
    events_name_list=[] #список имен ивентов        
    for events_name in events:
        events_name=events_name.find('a').text.strip().replace(' ', '_').replace(':','_').replace('.','_')
        if events_name in events_name_list:
            pass
        else:
            events_name_list.append(events_name) 
      
    events_name_list.pop(0) #удаляем первый элемент из списка, т.к. он нам не нужОн
    
    events_date_list=[date.find('span', class_='b-statistics__date').text.strip() for date in events] #генератор список дат ивентов      
            
    events_date_list.pop(0)
    
    events_location=[i.text.strip() for i in events2] #генератор список локаций ивента  
    
    events_location.pop(0)
    #записываем количество ивентов в csv файл 
    with open ( r'C:\Users\Media\parsing\ufc\all_evets.csv','w',newline='',encoding="utf-8-sig") as file:
        writer=csv.writer(file, delimiter=';')
        writer.writerow(
            (
                'Name_event',
                'Date',
                'Location'
            )
        )
    
    for i in range(0, len(events_name_list)):    
        with open (r'C:\Users\Media\parsing\ufc\all_evets.csv','a',newline='',encoding="utf-8-sig") as file: #дозаписывать файл следовательно флаг не 'w' a 'a', от слова append
            writer=csv.writer(file, delimiter=';') #этот метод вызывает писателя
            #этот метод записывает строку
            writer.writerow(
                (
                    events_name_list[i],
                    events_date_list[i],
                    events_location[i]
                )
            )
     
    slovar = dict(zip(events_name_list, events_url_list)) #объединяем списки в словарь
            
    for k,v in slovar.items(): #цикл создает папки и добавляет туда спарсенные страницы
        if not os.path.exists(f'C:/Users/Media/parsing/ufc/data/{k}'): #если не существует такой директории, то создать ее 
            os.mkdir(f'C:/Users/Media/parsing/ufc/data/{k}')
            
            req=requests.get(url=v,headers=headers)
    
            with open (f'C:/Users/Media/parsing/ufc/data/{k}/{k}.html','w', encoding='utf-8') as file:
                file.write(req.text)
            
            #сюда нужен код с добавлением CSV файла для списка боев в ивенте
            
            with open (f'C:/Users/Media/parsing/ufc/data/{k}/{k}.csv','w',newline='',encoding="utf-8-sig") as file:
                writer=csv.writer(file, delimiter=';')
                writer.writerow(
                    (
                        'Name_event',
                        'Fighter_1',
                        'Fighter_2',
                        'Winner',
                        'Weight',
                        'Method',
                        'Stroke',
                        'Round',
                        'Time'
                    )
                )
                
            soup=BeautifulSoup(req.text,'lxml') #парсим страницу

            events=soup.find('tbody', class_='b-fight-details__table-body').find_all('tr') #находи блок и ивенты в нем
            
            for event in events:
                try:
                    event_name = k # можно заменить на к словаря
                except:
                    event_name = 'No data'
                try:
                    fighter1=event.find_all('td')[1].find_all('a')[0].text.strip()
                except:
                    fighter1='No data'
                try: 
                    fighter2=event.find_all('td')[1].find_all('a')[1].text.strip()
                except:
                    fighter2='No data' 
                try: 
                    weight=event.find_all('td')[6].find('p').text.strip()
                except:
                    weight='No data'
                try: 
                    method=event.find_all('td')[7].find_all('p')[0].text.strip() 
                except:
                    method='No data'
                try: 
                    stroke=event.find_all('td')[7].find_all('p')[1].text.strip()
                    if len(stroke)>0:
                        stroke=stroke
                    else:
                        stroke='No data' 
                except:
                    stroke='No data'
                try: 
                    round=event.find_all('td')[8].find('p').text.strip() 
                except:
                    round='No data'
                try: 
                    timer=event.find_all('td')[9].find('p').text.strip() 
                except:
                    timer='No data'    
                    
                with open ( f'C:/Users/Media/parsing/ufc/data/{k}/{k}.csv','a',newline='',encoding="utf-8-sig") as file:
                    writer=csv.writer(file, delimiter=';')
                    writer.writerow(
                        (
                            event_name,
                            fighter1,
                            fighter2,
                            fighter1,
                            weight,
                            method,
                            stroke,
                            round,
                            timer
                        )
                    )
            
            #создаем две папки
            if not os.path.exists(f'C:/Users/Media/parsing/ufc/data/{k}/web'): #создаем папку web
                os.mkdir(f'C:/Users/Media/parsing/ufc/data/{k}/web')
            
            if not os.path.exists(f'C:/Users/Media/parsing/ufc/data/{k}/csv'): #создаем папку csv 
                os.mkdir(f'C:/Users/Media/parsing/ufc/data/{k}/csv')
            
            # в папу web добавляем страницы боев (целый блок, а не первая строка)
            with open (f'C:/Users/Media/parsing/ufc/data/{k}/{k}.html', encoding='utf-8') as file: #открываем сохраненную страницу ивента
                src=file.read()
                
            soup=BeautifulSoup(src, 'lxml') #парсим ее
            
            fights_events=soup.find_all('tr', class_='b-fight-details__table-row b-fight-details__table-row__hover js-fight-details-click') #находим нужный блок
            
            fights_url=[]
            
            fights_name=[]
            
            for i in fights_events:
                try:
                    url_fights=i.find('a', class_='b-flag b-flag_style_green' or 'b-flag b-flag_style_bordered').get('href') #находим url адрес боя
                    fights_url.append(url_fights)
                except:
                    url_fights=i.get('data-link')
                    fights_url.append(url_fights)
                
                name_fighter_1=i.find_all('a', class_='b-link b-link_style_black')[0].text.strip().replace(' ','_') #находим имя 1 бойца
                name_fighter_2=i.find_all('a', class_='b-link b-link_style_black')[1].text.strip().replace(' ','_') #находим имя 2 бойца
                ff=name_fighter_1+"_vs_"+name_fighter_2 #создаем комбинацию имен
                fights_name.append(ff)
    
            slovar2 = dict(zip(fights_name,fights_url)) #объединяем списки в словарь
            
            for m,j in slovar2.items():
                req=requests.get(url=j, headers=headers)
                with open (f'C:/Users/Media/parsing/ufc/data/{k}/web/{m}.html','w', encoding='utf-8') as file:
                    file.write(req.text)
                
                                            # блок добавляющий csv файлы
                with open (f'C:/Users/Media/parsing/ufc/data/{k}/web/{m}.html', encoding='utf-8') as file:
                    src=file.read()
                soup=BeautifulSoup(src,'lxml') #парсим страницу
                
                table=soup.find('div', class_='b-fight-details')
                try:
                    fighter1=table.find_all('a', class_='b-link b-fight-details__person-link')[0].text.strip().replace(' ', '_').replace(':','_').replace('.','_') #имя первого бойца
                except:
                    fighter1='No data'
                try:
                    fighter2=table.find_all('a', class_='b-link b-fight-details__person-link')[1].text.strip().replace(' ', '_').replace(':','_').replace('.','_') #имя второго бойца
                except:
                    fighter2='No data'
                try:
                    time_format=table.find_all('i',class_='b-fight-details__text-item')[2].text.strip().replace('Time format:',' ').strip() #формат боя
                except:
                    time_format='No data'
                try:
                    referee=table.find_all('i',class_='b-fight-details__text-item')[3].text.strip().replace('Referee:',' ').strip() #имя рефери
                except:
                    referee='No data'
                try:
                    judge1=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[0].find('span').text #имя первого судьи
                except:
                    judge1='No data'
                try:
                    judge2=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[1].find('span').text #имя второго судьи
                except:
                    judge2='No data'
                try:
                    judge3=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[2].find('span').text #имя третьего судьи
                except:
                    judge3='No data'    
                try:
                    judge1_rating_fighter1=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[0].text.replace('.','').split()[-3] #оценка 1 судьи для 1 бойца
                    judge1_rating_fighter2=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[0].text.replace('.','').split()[-1] #оценка 1 судьи для 2 бойца
                except:
                    judge1_rating_fighter1='No data'      
                    judge1_rating_fighter2='No data'
                try:
                    judge2_rating_fighter1=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[1].text.replace('.','').split()[-3] #оценка 2 судьи для 1 бойца
                    judge2_rating_fighter2=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[1].text.replace('.','').split()[-1] #оценка 2 судьи для 2 бойца      
                except:
                    judge2_rating_fighter1='No data'      
                    judge2_rating_fighter2='No data'
                try:
                    judge3_rating_fighter1=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[2].text.replace('.','').split()[-3] #оценка 3 судьи для 1 бойца
                    judge3_rating_fighter2=table.find_all('p',class_='b-fight-details__text')[1].find_all('i', class_='b-fight-details__text-item')[2].text.replace('.','').split()[-1] #оценка 3 судьи для 2 бойца      
                except:
                    judge3_rating_fighter1='No data'      
                    judge3_rating_fighter2='No data'
                try:
                    total=soup.find_all('section', class_='b-fight-details__section js-fight-section')[0].find('p').text.strip() #название раунда
                except:
                    total='Totals'

                    
                #находим строку Totals для сбора данных
                try:
                    total_table1=soup.find_all('table', style='width: 745px')[0]
                except:
                    total_table1='Error!'

                try:
                    total_table2=soup.find_all('table', style='width: 745px')[1]
                except:
                    total_table2='Error!'

                try:
                    total_table1_data=total_table1.find('tbody', class_='b-fight-details__table-body').find_all('td')
                except:
                    total_table1_data='Error'
                try:
                    total_table2_data=total_table2.find('tbody', class_='b-fight-details__table-body').find_all('td')
                except:
                    total_table2_data='Error'

                #данные из первой таблицы totals
                try:
                    kd1=int(total_table1_data[1].find_all('p')[0].text)
                    kd2=int(total_table1_data[1].find_all('p')[1].text)
                    acc_sig_str1=int(total_table1_data[2].find_all('p')[0].text.split()[0])
                    acc_sig_str2=int(total_table1_data[2].find_all('p')[1].text.split()[0])
                    sig_str1=int(total_table1_data[2].find_all('p')[0].text.split()[2])
                    sig_str2=int(total_table1_data[2].find_all('p')[1].text.split()[2])
                    sig_str1_prc=total_table1_data[3].find_all('p')[0].text.strip()
                    sig_str2_prc=total_table1_data[3].find_all('p')[1].text.strip()
                    acc_total_str1=int(total_table1_data[4].find_all('p')[0].text.split()[0])
                    acc_total_str2=int(total_table1_data[4].find_all('p')[1].text.split()[0])
                    total_str1=int(total_table1_data[4].find_all('p')[0].text.split()[2])
                    total_str2=int(total_table1_data[4].find_all('p')[1].text.split()[2])
                    acc_td1=int(total_table1_data[5].find_all('p')[0].text.split()[0])
                    acc_td2=int(total_table1_data[5].find_all('p')[1].text.split()[0])
                    td1=int(total_table1_data[5].find_all('p')[0].text.split()[2])
                    td2=int(total_table1_data[5].find_all('p')[1].text.split()[2])
                    td1_prc=total_table1_data[6].find_all('p')[0].text.strip()
                    td2_prc=total_table1_data[6].find_all('p')[1].text.strip()
                    sub_att1=int(total_table1_data[7].find_all('p')[0].text)
                    sub_att2=int(total_table1_data[7].find_all('p')[1].text)
                    rev1=int(total_table1_data[8].find_all('p')[0].text)
                    rev2=int(total_table1_data[8].find_all('p')[1].text)
                    ctrl1=total_table1_data[9].find_all('p')[0].text.strip()
                    ctrl2=total_table1_data[9].find_all('p')[1].text.strip()

                    #данные из второй таблицы totals

                    acc_head1=int(total_table2_data[3].find_all('p')[0].text.split()[0])
                    acc_head2=int(total_table2_data[3].find_all('p')[1].text.split()[0])
                    head1=int(total_table2_data[3].find_all('p')[0].text.split()[2])
                    head2=int(total_table2_data[3].find_all('p')[1].text.split()[2])
                    acc_body1=int(total_table2_data[4].find_all('p')[0].text.split()[0])
                    acc_body2=int(total_table2_data[4].find_all('p')[1].text.split()[0])
                    body1=int(total_table2_data[4].find_all('p')[0].text.split()[2])
                    body2=int(total_table2_data[4].find_all('p')[1].text.split()[2])
                    acc_leg1=int(total_table2_data[5].find_all('p')[0].text.split()[0])
                    acc_leg2=int(total_table2_data[5].find_all('p')[1].text.split()[0])
                    leg1=int(total_table2_data[5].find_all('p')[0].text.split()[2])
                    leg2=int(total_table2_data[5].find_all('p')[1].text.split()[2])
                    acc_distance1=int(total_table2_data[6].find_all('p')[0].text.split()[0])
                    acc_distance2=int(total_table2_data[6].find_all('p')[1].text.split()[0])
                    distance1=int(total_table2_data[6].find_all('p')[0].text.split()[2])
                    distance2=int(total_table2_data[6].find_all('p')[1].text.split()[2])
                    acc_clinch1=int(total_table2_data[7].find_all('p')[0].text.split()[0])
                    acc_clinch2=int(total_table2_data[7].find_all('p')[1].text.split()[0])
                    clinch1=int(total_table2_data[7].find_all('p')[0].text.split()[2])
                    clinch2=int(total_table2_data[7].find_all('p')[1].text.split()[2])
                    acc_ground1=int(total_table2_data[8].find_all('p')[0].text.split()[0])
                    acc_ground2=int(total_table2_data[8].find_all('p')[1].text.split()[0])
                    ground1=int(total_table2_data[8].find_all('p')[0].text.split()[2])
                    ground2=int(total_table2_data[8].find_all('p')[1].text.split()[2])
                except:
                    kd1='No data'
                    kd2='No data'
                    acc_sig_str1='No data'
                    acc_sig_str2='No data'
                    sig_str1='No data'
                    sig_str2='No data'
                    sig_str1_prc='No data'
                    sig_str2_prc='No data'
                    acc_total_str1='No data'
                    acc_total_str2='No data'
                    total_str1='No data'
                    total_str2='No data'
                    acc_td1='No data'
                    acc_td2='No data'
                    td1='No data'
                    td2='No data'
                    td1_prc='No data'
                    td2_prc='No data'
                    sub_att1='No data'
                    sub_att2='No data'
                    rev1='No data'
                    rev2='No data'
                    ctrl1='No data'
                    ctrl2='No data'
                    acc_head1='No data'
                    acc_head2='No data'
                    head1='No data'
                    head2='No data'
                    acc_body1='No data'
                    acc_body2='No data'
                    body1='No data'
                    body2='No data'
                    acc_leg1='No data'
                    acc_leg2='No data'
                    leg1='No data'
                    leg2='No data'
                    acc_distance1='No data'
                    acc_distance2='No data'
                    distance1='No data'
                    distance2='No data'
                    acc_clinch1='No data'
                    acc_clinch2='No data'
                    clinch1='No data'
                    clinch2='No data'
                    acc_ground1='No data'
                    acc_ground2='No data'
                    ground1='No data'
                    ground2='No data'
                
                #создаем csv и записываем данные из строки Totals
                with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter1}.csv','w',newline='',encoding="utf-8-sig") as file:
                    writer=csv.writer(file, delimiter=';')
                    writer.writerow(
                        (
                            'fighter','opponent','winner','time format','refere','judge1','judge2','judge3','rating1','rating2','rating3','round',
                            'KD','acc. sig. str.','sig. str.','sig. str.%','acc. ttl. str.','ttl. str.','acc. td.','td.','td.%','sub. att.','rev','ctrl',
                            'acc. head','head','acc. body', 'body', 'acc. leg', 'leg', 'acc. distance', 'distance', 'acc. clinch','clinch','acc. ground','ground'
                        )
                    )

                with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter1}.csv','a',newline='',encoding="utf-8-sig") as file:
                    writer=csv.writer(file, delimiter=';')
                    writer.writerow(
                        (
                            fighter1,fighter2,fighter1,time_format,referee,judge1,judge2,judge3,judge1_rating_fighter1,judge2_rating_fighter1,judge3_rating_fighter1,total,
                            kd1,acc_sig_str1,sig_str1,sig_str1_prc,acc_total_str1,total_str1,acc_td1,td1,td1_prc,sub_att1,rev1,ctrl1,
                            acc_head1,head1,acc_body1, body1, acc_leg1, leg1, acc_distance1, distance1, acc_clinch1,clinch1,acc_ground1,ground1
                        )
                    )

                with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter2}.csv','w',newline='',encoding="utf-8-sig") as file:
                    writer=csv.writer(file, delimiter=';')
                    writer.writerow(
                        (
                            'fighter','opponent','winner','time format','refere','judge1','judge2','judge3','rating1','rating2','rating3','round',
                            'KD','acc. sig. str.','sig. str.','sig. str.%','acc. ttl. str.','ttl. str.','acc. td.','td.','td.%','sub. att.','rev','ctrl',
                            'acc. head','head','acc. body', 'body', 'acc. leg', 'leg', 'acc. distance', 'distance', 'acc. clinch','clinch','acc. ground','ground'
                        )
                    )
                    
                with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter2}.csv','a',newline='',encoding="utf-8-sig") as file:
                    writer=csv.writer(file, delimiter=';')
                    writer.writerow(
                        (
                            fighter2,fighter1,fighter1,time_format,referee,judge1,judge2,judge3,judge1_rating_fighter2,judge2_rating_fighter2,judge3_rating_fighter2,total,
                            kd2,acc_sig_str2,sig_str2,sig_str2_prc,acc_total_str2,total_str2,acc_td2,td2,td2_prc,sub_att2,rev2,ctrl2,
                            acc_head2,head2,acc_body2, body2, acc_leg2, leg2, acc_distance2, distance2, acc_clinch2,clinch2,acc_ground2,ground2
                        )
                    )
                # написать цикл записывающий все это в таблицу
                try: 
                    table1=soup.find_all('table',class_='b-fight-details__table js-fight-table')[0] #таблица по раундам
                    table2=soup.find_all('table',class_='b-fight-details__table js-fight-table')[1] #таблица по раундам
                    table1_rows=table1.find_all('tr',class_='b-fight-details__table-row')
                    table2_rows=table2.find_all('tr',class_='b-fight-details__table-row')
                except:
                    table1='No data'
                    table2='No data'
                    table1_rows='n'
                    table2_rows='n'
                
                for i in range(1, len(table1_rows)):
                    try:
                        #находим показатели
                        kd1=int(table1_rows[i].find_all('td')[1].find_all('p')[0].text)
                        kd2=int(table1_rows[i].find_all('td')[1].find_all('p')[1].text)
                        acc_sig_str1=int(table1_rows[i].find_all('td')[2].find_all('p')[0].text.split()[0])
                        acc_sig_str2=int(table1_rows[i].find_all('td')[2].find_all('p')[1].text.split()[0])
                        sig_str1=int(table1_rows[i].find_all('td')[2].find_all('p')[0].text.split()[2])
                        sig_str2=int(table1_rows[i].find_all('td')[2].find_all('p')[1].text.split()[2])
                        sig_str1_prc=table1_rows[i].find_all('td')[3].find_all('p')[0].text.strip()
                        sig_str2_prc=table1_rows[i].find_all('td')[3].find_all('p')[1].text.strip()
                        acc_total_str1=int(table1_rows[i].find_all('td')[4].find_all('p')[0].text.split()[0])
                        acc_total_str2=int(table1_rows[i].find_all('td')[4].find_all('p')[1].text.split()[0])
                        total_str1=int(table1_rows[i].find_all('td')[4].find_all('p')[0].text.split()[2])
                        total_str2=int(table1_rows[i].find_all('td')[4].find_all('p')[1].text.split()[2])
                        acc_td1=int(table1_rows[i].find_all('td')[5].find_all('p')[0].text.split()[0])
                        acc_td2=int(table1_rows[i].find_all('td')[5].find_all('p')[1].text.split()[0])
                        td1=int(table1_rows[i].find_all('td')[5].find_all('p')[0].text.split()[2])
                        td2=int(table1_rows[i].find_all('td')[5].find_all('p')[1].text.split()[2])
                        td1_prc=table1_rows[i].find_all('td')[6].find_all('p')[0].text.strip()
                        td2_prc=table1_rows[i].find_all('td')[6].find_all('p')[1].text.strip()
                        sub_att1=int(table1_rows[i].find_all('td')[7].find_all('p')[0].text)
                        sub_att2=int(table1_rows[i].find_all('td')[7].find_all('p')[1].text)
                        rev1=int(table1_rows[i].find_all('td')[8].find_all('p')[0].text)
                        rev2=int(table1_rows[i].find_all('td')[8].find_all('p')[1].text)
                        ctrl1=table1_rows[i].find_all('td')[9].find_all('p')[0].text.strip()
                        ctrl2=table1_rows[i].find_all('td')[9].find_all('p')[1].text.strip()
                        acc_head1=int(table2_rows[i].find_all('td')[3].find_all('p')[0].text.split()[0])
                        acc_head2=int(table2_rows[i].find_all('td')[3].find_all('p')[1].text.split()[0])
                        head1=int(table2_rows[i].find_all('td')[3].find_all('p')[0].text.split()[2])
                        head2=int(table2_rows[i].find_all('td')[3].find_all('p')[1].text.split()[2])
                        acc_body1=int(table2_rows[i].find_all('td')[4].find_all('p')[0].text.split()[0])
                        acc_body2=int(table2_rows[i].find_all('td')[4].find_all('p')[1].text.split()[0])
                        body1=int(table2_rows[i].find_all('td')[4].find_all('p')[0].text.split()[2])
                        body2=int(table2_rows[i].find_all('td')[4].find_all('p')[1].text.split()[2])
                        acc_leg1=int(table2_rows[i].find_all('td')[5].find_all('p')[0].text.split()[0])
                        acc_leg2=int(table2_rows[i].find_all('td')[5].find_all('p')[1].text.split()[0])
                        leg1=int(table2_rows[i].find_all('td')[5].find_all('p')[0].text.split()[2])
                        leg2=int(table2_rows[i].find_all('td')[5].find_all('p')[1].text.split()[2])
                        acc_distance1=int(table2_rows[i].find_all('td')[6].find_all('p')[0].text.split()[0])
                        acc_distance2=int(table2_rows[i].find_all('td')[6].find_all('p')[1].text.split()[0])
                        distance1=int(table2_rows[i].find_all('td')[6].find_all('p')[0].text.split()[2])
                        distance2=int(table2_rows[i].find_all('td')[6].find_all('p')[1].text.split()[2])
                        acc_clinch1=int(table2_rows[i].find_all('td')[7].find_all('p')[0].text.split()[0])
                        acc_clinch2=int(table2_rows[i].find_all('td')[7].find_all('p')[1].text.split()[0])
                        clinch1=int(table2_rows[i].find_all('td')[7].find_all('p')[0].text.split()[2])
                        clinch2=int(table2_rows[i].find_all('td')[7].find_all('p')[1].text.split()[2])
                        acc_ground1=int(table2_rows[i].find_all('td')[8].find_all('p')[0].text.split()[0])
                        acc_ground2=int(table2_rows[i].find_all('td')[8].find_all('p')[1].text.split()[0])
                        ground1=int(table2_rows[i].find_all('td')[8].find_all('p')[0].text.split()[2])
                        ground2=int(table2_rows[i].find_all('td')[8].find_all('p')[1].text.split()[2])
                    except:
                        kd1='No data'
                        kd2='No data'
                        acc_sig_str1='No data'
                        acc_sig_str2='No data'
                        sig_str1='No data'
                        sig_str2='No data'
                        sig_str1_prc='No data'
                        sig_str2_prc='No data'
                        acc_total_str1='No data'
                        acc_total_str2='No data'
                        total_str1='No data'
                        total_str2='No data'
                        acc_td1='No data'
                        acc_td2='No data'
                        td1='No data'
                        td2='No data'
                        td1_prc='No data'
                        td2_prc='No data'
                        sub_att1='No data'
                        sub_att2='No data'
                        rev1='No data'
                        rev2='No data'
                        ctrl1='No data'
                        ctrl2='No data'
                        acc_head1='No data'
                        acc_head2='No data'
                        head1='No data'
                        head2='No data'
                        acc_body1='No data'
                        acc_body2='No data'
                        body1='No data'
                        body2='No data'
                        acc_leg1='No data'
                        acc_leg2='No data'
                        leg1='No data'
                        leg2='No data'
                        acc_distance1='No data'
                        acc_distance2='No data'
                        distance1='No data'
                        distance2='No data'
                        acc_clinch1='No data'
                        acc_clinch2='No data'
                        clinch1='No data'
                        clinch2='No data'
                        acc_ground1='No data'
                        acc_ground2='No data'
                        ground1='No data'
                        ground2='No data'
                    
                    try:
                        #записываем показатели
                        with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter1}.csv','a',newline='',encoding="utf-8-sig") as file:
                            writer=csv.writer(file, delimiter=';')
                            writer.writerow(
                                (
                                    fighter1,fighter2,fighter1,time_format,referee,judge1,judge2,judge3,judge1_rating_fighter1,judge2_rating_fighter1,judge3_rating_fighter1,f'{i}_round',
                                    kd1,acc_sig_str1,sig_str1,sig_str1_prc,acc_total_str1,total_str1,acc_td1,td1,td1_prc,sub_att1,rev1,ctrl1,
                                    acc_head1,head1,acc_body1, body1, acc_leg1, leg1, acc_distance1, distance1, acc_clinch1,clinch1,acc_ground1,ground1
                                )
                            )
                
                        with open ( f'C:/Users/Media/parsing/ufc/data/{k}/csv/{fighter2}.csv','a',newline='',encoding="utf-8-sig") as file:
                            writer=csv.writer(file, delimiter=';')
                            writer.writerow(
                                (
                                    fighter2,fighter1,fighter1,time_format,referee,judge1,judge2,judge3,judge1_rating_fighter2,judge2_rating_fighter2,judge3_rating_fighter2,f'{i}_round',
                                    kd2,acc_sig_str2,sig_str2,sig_str2_prc,acc_total_str2,total_str2,acc_td2,td2,td2_prc,sub_att2,rev2,ctrl2,
                                    acc_head2,head2,acc_body2, body2, acc_leg2, leg2, acc_distance2, distance2, acc_clinch2,clinch2,acc_ground2,ground2
                                )
                            )
                    except:
                        pass
           


def main():
    get_data(url='http://ufcstats.com/statistics/events/completed?page=all')
    
if __name__=='__main__':
    main()
